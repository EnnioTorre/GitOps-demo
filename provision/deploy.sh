#!/bin/bash

function usage() {
    echo
    echo "Usage:"
    echo " $0 [command] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " $0 deploy --project-suffix mydemo"
    echo
    echo "COMMANDS:"
    echo "   deploy                   Set up the demo projects and deploy demo apps"
    echo "   delete                   Clean up and remove demo projects and objects"
    echo 
    echo "OPTIONS:"
    echo "   --enable-monitoring        Optional    deploy monitoring stack: Prometheus+Grafana"
    echo "   --oc-options               Optional    oc client options to pass to all oc commands e.g. --server https://my.openshift.com"
    echo
}

ARG_COMMAND=
ARG_OC_OPS=
ARG_ENABLE_MONITORING=false

while :; do
    case $1 in
        deploy)
            ARG_COMMAND=deploy
            ;;
        delete)
            ARG_COMMAND=delete
            ;;
        --oc-options)
            if [ -n "$2" ]; then
                ARG_OC_OPS=$2
                shift
            else
                printf 'ERROR: "--oc-options" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --enable-monitoring)
            ARG_ENABLE_MONITORING=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            shift
            ;;
        *) # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done


################################################################################
# CONFIGURATION                                                                #
################################################################################

LOGGEDIN_USER=$(oc $ARG_OC_OPS whoami)
if [ "$?" -ne 0 ]
   then
      echo "you are not logged in!"
   fi
APP_NAME="demobakery"

GITHUB_APP_URL="https://github.com/EnnioTorre/vaadin-demo-bakery-app.git"


function deploy() {

  local envs="develop"
  local project
  local pipe_sa
 
  for ENV in $envs
  do
    project=$(oc $ARG_OC_OPS get project -o name|grep $ENV-$APP_NAME)
    if [ -z "$project" ]
    then
        oc $ARG_OC_OPS new-project $ENV-$APP_NAME   --display-name="${APP_NAME} - Dev" 1>/dev/null
    else 
        echo "project with name $ENV-$APP_NAME already exists" 
    fi
    
    sleep 10

    pipe_sa=$(oc $ARG_OC_OPS -n $ENV-$APP_NAME get sa pipeline)
    if [ -z "$pipe_sa" ]
    then
        echo "please deploy the Openshift pipelines Operator first!"
        exit -1
    fi

    sleep 2

    local params="https://raw.githubusercontent.com/EnnioTorre/GitOps-demo/master/manifests/$ENV/tekton/values.yaml"
    local pipeline="https://raw.githubusercontent.com/EnnioTorre/GitOps-demo/master/manifests/$ENV/tekton/demobackery-pipeline-v0.0.1.tgz?raw=true"
    local app_params="https://raw.githubusercontent.com/EnnioTorre/GitOps-demo/master/manifests/$ENV/helm/values.yaml"
    local manifests="https://raw.githubusercontent.com/EnnioTorre/GitOps-demo/master/manifests/$ENV/helm/demobackery-pipeline-v0.0.1.tgz?raw=true"

    echo "create pipeline in $ENV-$APP_NAME ......."
    helm template -f $pipeline_params ${APP_NAME}-pipeline --set namespace=$ENV-$APP_NAME --set app_name=$APP_NAME $pipeline |oc apply -f -

    echo "install application's manifests in $ENV-$APP_NAME ......."
    helm upgrade --install -f $app_params  ${APP_NAME}-pipeline --set namespace=$ENV-$APP_NAME --set app_name=$APP_NAME $manifests
  done  
}


function deploy_monitoring() {

  ENV="dev"
  APP_MON="prometheus"
  local operator=$(oc $ARG_OC_OPS -n $ENV-$APP_NAME get po -o name|grep $APP_MON-operator)

  if [ -z "$operator" ]
  then
      echo "please deploy and $APP_MON-operator first!"
      exit -1
  fi

  echo "deploy $APP_MON in dev-$APP_NAME ......."
  oc $ARG_OC_OPS process -p APP_NAME=$APP_NAME -p PROJECT=$ENV-$APP_NAME -f ../monitoring/$APP_MON/$APP_MON.yaml -n $ENV-$APP_NAME|oc $ARG_OC_OPS apply -n $ENV-$APP_NAME -f -
  
  sleep 2
  
  APP_MON="grafana"
  operator=$(oc $ARG_OC_OPS -n $ENV-$APP_NAME get po -o name|grep $APP_MON-operator)

  if [ -z "$operator" ]
  then
      echo "please deploy and $APP_MON-operator first!"
      exit -1
  fi

  echo "deploy $APP_MON in $ENV-$APP_NAME ......."
  oc $ARG_OC_OPS process -p APP_NAME=$APP_NAME -p PROJECT=$ENV-$APP_NAME -f ../monitoring/$APP_MON/$APP_MON.yaml -n $ENV-$APP_NAME|oc $ARG_OC_OPS apply -n $ENV-$APP_NAME -f -

}

################################################################################
# MAIN                                                                         #
################################################################################

if [ "$ARG_COMMAND" == "deploy" ]
then
  deploy
  if [ "$ARG_ENABLE_MONITORING" == "true" ]
  then
    deploy_monitoring
  fi
  echo "RUN YOUR PIPELINE !"
fi

if [ "$ARG_COMMAND" == "delete" ]
then
  echo "cleaning up ......"
  ENV="dev"
  oc $ARG_OC_OPS project delete $ENV-$APP_NAME
  ENV="prod"
  oc $ARG_OC_OPS project delete $ENV-$APP_NAME
  echo "PROJECT DELETED!"
fi



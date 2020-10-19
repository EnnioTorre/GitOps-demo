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

  local envs="develop stage prod"
  local project
  local pipe_sa
 
  for env in $env
  do
    project=$(oc $ARG_OC_OPS get project -o name|grep $env-$APP_NAME)
    if [ -z "$project" ]
    then
        oc $ARG_OC_OPS new-project $env-$APP_NAME   --display-name="${APP_NAME} - Dev" 1>/dev/null
    else 
        echo "project with name $env-$APP_NAME already exists" 
    fi
    
    sleep 10

    pipe_sa=$(oc $ARG_OC_OPS -n $env-$APP_NAME get sa pipeline)
    if [ -z "$pipe_sa" ]
    then
        echo "please deploy the Openshift pipelines Operator first!"
        exit -1
    fi


  local 

  project=$(oc $ARG_OC_OPS get project -o name|grep prod-$APP_NAME)
  if [ -z "$project" ]
  then
       oc $ARG_OC_OPS new-project prod-$APP_NAME   --display-name="${APP_NAME} - Prod" 1>/dev/null
  else 
       echo "project with name prod-$APP_NAME already exists"
  fi
  

  sleep 2
  local jenkins=$(oc $ARG_OC_OPS -n dev-$APP_NAME get dc -o name|grep jenkins)
  if [ -z "$jenkins" ]
  then
      echo "create jenkins in dev-$APP_NAME ......." 
      oc $ARG_OC_OPS new-app jenkins-ephemeral -n dev-$APP_NAME
  else 
     echo "Jenkins already exists" 
  fi
 

  sleep 2

  local template="https://raw.githubusercontent.com/EnnioTorre/vaadin-demo-bakery-app/master/kubernetes/$ENV/deployment.yaml"
  local params="../appbackery/artifacts/$ENV/params"
  local pipeline="https://raw.githubusercontent.com/EnnioTorre/vaadin-demo-bakery-app/master/kubernetes/$ENV/pipeline.yaml"

  echo "deploy application artifacts in $ENV-$APP_NAME ......."
  oc $ARG_OC_OPS process -p APP_NAME=$APP_NAME --param-file $params -f $template -n $ENV-$APP_NAME|oc $ARG_OC_OPS apply -n $ENV-$APP_NAME -f -

  sleep 2

  echo "deploy CI/CD jenkins pipeline in $ENV-$APP_NAME ......."
  oc $ARG_OC_OPS process -p APP_NAME=$APP_NAME --param-file $params -f $pipeline|oc $ARG_OC_OPS apply -f -
  sleep 2
  
  ENV="prod"

  template="https://raw.githubusercontent.com/EnnioTorre/vaadin-demo-bakery-app/master/kubernetes/$ENV/deployment.yaml"
  params="../appbackery/artifacts/$ENV/params"

  echo "deploy application artifacts in $ENV-$APP_NAME ......."
  oc $ARG_OC_OPS process -p APP_NAME=$APP_NAME --param-file $params -f $template -n $ENV-$APP_NAME|oc $ARG_OC_OPS apply -n $ENV-$APP_NAME -f -
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



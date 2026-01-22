#!/bin/bash

##################################################################
## DEFAULT VALUES HERE => should be empty for final/public version
# pulse
VAR_PULSE_PROTOCOL="http"
VAR_PULSE_HOST="ct-pulse.home"
VAR_PULSE_PORT="7655"
VAR_PULSE_KEY="f3b0243219206db7ad93a0cdb869cdc4f1cc3a3782feda7cb0563f63caa1ccc3"
# mqtt
VAR_MQTT_HOST="vm-ha-docker.home"
VAR_MQTT_PORT="1883"
VAR_MQTT_PULSE_TOPIC="pulse2mqtt"
VAR_MQTT_HA_TOPIC="homeassistant"

VAR_PULSE_BASE_URL=""


##################################################################
##################################################################
## FUNCTIONS and TOOLS  
##################################################################
##################################################################
call_api () {
        L_URL="$1"
        L_RESPONSE="$(curl -s -H "X-API-TOKEN: ${VAR_PULSE_KEY}"  ${VAR_PULSE_BASE_URL}${L_URL} )"
        echo "${L_RESPONSE}"
}


publish_mqtt_ha_config_sensor(){
        L_HA_SUBTOPIC="sensor"
        L_SUBTOPIC="$1"
        L_FIELD="$2"
        L_ACCESS_TEMPLATE="$3"
        L_NAME="$4"
        L_DEVICE_JSON="$5"

        L_MQTT_TOPIC="${VAR_MQTT_PULSE_TOPIC}/${L_SUBTOPIC}"
        L_FULL_TOPIC="${VAR_MQTT_HA_TOPIC}/${L_HA_SUBTOPIC}/${L_SUBTOPIC}_${L_FIELD}/config"

        L_JSON="{\"state_topic\":\"${L_MQTT_TOPIC}\", \"value_template\":\"${L_ACCESS_TEMPLATE}\", \"name\":\"${L_NAME}\", \"unique_id\":\"${L_SUBTOPIC}_${L_FIELD}\", ${L_DEVICE_JSON}  } "
        L_RESPONSE="$(mosquitto_pub  -h ${VAR_MQTT_HOST} -p ${VAR_MQTT_PORT} -t "${L_FULL_TOPIC}" -m "${L_JSON}" )"
        #echo " DEBUG: ${L_JSON}" >&2
}


publish_mqtt_pulse_topic(){
        L_SUBTOPIC="$1"
        L_JSON="$2"

        L_FULL_TOPIC="${VAR_MQTT_PULSE_TOPIC}/${L_SUBTOPIC}"
        L_RESPONSE="$(mosquitto_pub  -h ${VAR_MQTT_HOST} -p ${VAR_MQTT_PORT} -t "${L_FULL_TOPIC}" -m "${L_JSON}" )"
}


publish_version_api() {
        L_FORCE_UPDATE="$1"
        RESPONSE_TMP="$( call_api ${VAR_API_VERSION})"
        #echo " CONTENT OF RESPONSE: ${RESPONSE}"
        RESPONSE="$( echo "${RESPONSE_TMP}" | jq -f jq_filter_version.txt)"

        if [ "${L_FORCE_UPDATE}" == "yes" ] ; 
        then
                echo "${RESPONSE}" | jq --tab >&2
                L_DEVICE_JSON='"device":{ "identifiers":[ "pulse_top" ], "name":"Pulse Top" } '
                publish_mqtt_ha_config_sensor   "pulse_version" "version" "{{value_json.version}}" "Current Version" "${L_DEVICE_JSON}" 
                publish_mqtt_ha_config_sensor   "pulse_version" "latestversion" "{{value_json.latestVersion}}" "Latest Version" "${L_DEVICE_JSON}" 
                publish_mqtt_ha_config_sensor   "pulse_version" "deploymenttype" "{{value_json.deploymentType}}" "Deployment Type" "${L_DEVICE_JSON}" 
                publish_mqtt_ha_config_sensor   "pulse_version" "channel" "{{value_json.channel}}" "Channel" "${L_DEVICE_JSON}" 

                publish_mqtt_pulse_topic        "pulse_version" "${RESPONSE}"
        else
                echo "${RESPONSE}" | jq --tab >&2
                publish_mqtt_pulse_topic "pulse_version" "${RESPONSE}"
        fi
}




##################################################################
##################################################################
## MAIN  
##################################################################
##################################################################


##################################################################
# Loop through arguments
for arg in "$@"; do
   case "$arg" in
      pulse_protocol=*) VAR_PULSE_PROTOCOL="${arg#*=}" ;;
      pulse_host=*)     VAR_PULSE_HOST="${arg#*=}" ;;
      pulse_port=*)     VAR_PULSE_PORT="${arg#*=}" ;;
      pulse_key=*)      VAR_PULSE_KEY="${arg#*=}" ;;
   esac
done

##################################################################
## DERIVATE/CONCATENATE 
VAR_PULSE_BASE_URL="${VAR_PULSE_PROTOCOL}://${VAR_PULSE_HOST}:${VAR_PULSE_PORT}"

## debug input parameters
echo "VAR_PULSE_BASE_URL=\"${VAR_PULSE_BASE_URL}\""
#echo "VAR_PULSE_KEY=\"${VAR_PULSE_KEY}\""

##################################################################
## TEST PING  
/usr/bin/ping -c1 ${VAR_PULSE_HOST} >/dev/null
if [ $? -ne 0 ]; then
    echo "ping failed to ${VAR_PULSE_HOST}" 
    exit 1
fi


##################################################################
## EXPORT   => could be usefull if we call scripts , it will already be defined :-)
export VAR_PULSE_PROTOCOL
export VAR_PULSE_HOST
export VAR_PULSE_PORT
export VAR_PULSE_KEY
export VAR_PULSE_BASE_URL

VAR_API_HEALTH="/api/health"
VAR_API_VERSION="/api/version"
VAR_API_STATE="/api/state"


##################################################################
## INFINITE LOOP
LOOP_CPT=0
L_CONTINUE=true
while [ $L_CONTINUE} ] 
do
        echo "===== MAIN_LOOP_BEGIN ${LOOP_CPT}" >&2
        if [ "$((LOOP_CPT%60))" -eq  0 ] ;
        then
                # publish data and update HA automatic discovery
                publish_version_api yes
        else
                if [ "$((LOOP_CPT%10))" -eq  0 ] ;
                then
                        #only push data 
                        publish_version_api no
                fi
        fi

        LOOP_CPT=$((LOOP_CPT+1))
        LOOP_CPT=$((LOOP_CPT%300))
        sleep 1
done
exit 0 

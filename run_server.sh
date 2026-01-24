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

publish_mqtt_ha_config_binary_sensor(){
	L_HA_SUBTOPIC="binary_sensor"
        L_SUBTOPIC="$1"
	L_FIELD="$2"
	L_ACCESS_TEMPLATE="$3"
	L_NAME="$4"
	L_DEVICE_JSON="$5"

	L_MQTT_TOPIC="${VAR_MQTT_PULSE_TOPIC}/${L_SUBTOPIC}"
	L_FULL_TOPIC="${VAR_MQTT_HA_TOPIC}/${L_HA_SUBTOPIC}/pulse/${L_SUBTOPIC}_${L_FIELD}/config"
	
	L_EXTRA_JSON="\"payload_on\":true, \"payload_off\":false"

	L_JSON="{\"state_topic\":\"${L_MQTT_TOPIC}\", \"value_template\":\"${L_ACCESS_TEMPLATE}\", \"name\":\"${L_NAME}\", \"unique_id\":\"${L_SUBTOPIC}_${L_FIELD}\", ${L_EXTRA_JSON}, ${L_DEVICE_JSON}  } "
        L_RESPONSE="$(mosquitto_pub  -h ${VAR_MQTT_HOST} -p ${VAR_MQTT_PORT} -t "${L_FULL_TOPIC}" -m "${L_JSON}" )"
	#echo " DEBUG: ${L_JSON}" >&2
}


publish_mqtt_ha_config_sensor(){
	L_HA_SUBTOPIC="sensor"
        L_SUBTOPIC="$1"
	L_FIELD="$2"
	L_ACCESS_TEMPLATE="$3"
	L_NAME="$4"
	L_DEVICE_JSON="$5"

	L_MQTT_TOPIC="${VAR_MQTT_PULSE_TOPIC}/${L_SUBTOPIC}"
	L_FULL_TOPIC="${VAR_MQTT_HA_TOPIC}/${L_HA_SUBTOPIC}/pulse/${L_SUBTOPIC}_${L_FIELD}/config"

	L_JSON="{\"state_topic\":\"${L_MQTT_TOPIC}\", \"value_template\":\"${L_ACCESS_TEMPLATE}\", \"name\":\"${L_NAME}\", \"unique_id\":\"${L_SUBTOPIC}_${L_FIELD}\", ${L_DEVICE_JSON}  } "
        L_RESPONSE="$(mosquitto_pub  -h ${VAR_MQTT_HOST} -p ${VAR_MQTT_PORT} -t "${L_FULL_TOPIC}" -m "${L_JSON}" )"
	#echo " DEBUG: ${L_JSON}" >&2
}

publish_mqtt_ha_config_sensor_measure(){
	L_HA_SUBTOPIC="sensor"
        L_SUBTOPIC="$1"
	L_FIELD="$2"
	L_ACCESS_TEMPLATE="$3"
	L_NAME="$4"
	L_DEVICE_JSON="$5"

	L_EXTRA_JSON="\"state_class\": \"measurement\" "

	L_MQTT_TOPIC="${VAR_MQTT_PULSE_TOPIC}/${L_SUBTOPIC}"
	L_FULL_TOPIC="${VAR_MQTT_HA_TOPIC}/${L_HA_SUBTOPIC}/pulse/${L_SUBTOPIC}_${L_FIELD}/config"

	L_JSON="{\"state_topic\":\"${L_MQTT_TOPIC}\", \"value_template\":\"${L_ACCESS_TEMPLATE}\", \"name\":\"${L_NAME}\", \"unique_id\":\"${L_SUBTOPIC}_${L_FIELD}\", ${L_EXTRA_JSON},  ${L_DEVICE_JSON}  } "
        L_RESPONSE="$(mosquitto_pub  -h ${VAR_MQTT_HOST} -p ${VAR_MQTT_PORT} -t "${L_FULL_TOPIC}" -m "${L_JSON}" )"
}



publish_mqtt_ha_config_gen(){

   case "$1" in
      sensor) 
		publish_mqtt_ha_config_sensor "$2" "$3" "$4" "$5" "$6"
		;;
      sensor_measure) 
		publish_mqtt_ha_config_sensor_measure "$2" "$3" "$4" "$5" "$6"
		;;

      binary_sensor) 
		publish_mqtt_ha_config_binary_sensor "$2" "$3" "$4" "$5" "$6"
		;;
   esac
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
	RESPONSE="$( echo "${RESPONSE_TMP}" | jq --tab -f jq_filter_version.txt)"

	if [ "${L_FORCE_UPDATE}" == "yes" ] ; 
	then
		L_DEVICE_JSON='"device":{ "identifiers":[ "pulse_top" ], "name":"Pulse Top" } '
		publish_mqtt_ha_config_gen	"sensor" "pulse_version" "version" "{{value_json.version}}" "Current Version" "${L_DEVICE_JSON}" 
		publish_mqtt_ha_config_gen	"sensor" "pulse_version" "latestversion" "{{value_json.latestVersion}}" "Latest Version" "${L_DEVICE_JSON}" 
		publish_mqtt_ha_config_gen	"sensor" "pulse_version" "deploymenttype" "{{value_json.deploymentType}}" "Deployment Type" "${L_DEVICE_JSON}" 
		publish_mqtt_ha_config_gen	"sensor" "pulse_version" "channel" "{{value_json.channel}}" "Channel" "${L_DEVICE_JSON}" 
		publish_mqtt_ha_config_gen	"binary_sensor"	"pulse_version" "updateavailable" "{{value_json.updateAvailale}}" "Update Available" "${L_DEVICE_JSON}" 


		publish_mqtt_pulse_topic 	"pulse_version" "${RESPONSE}"
	else
		publish_mqtt_pulse_topic "pulse_version" "${RESPONSE}"
	fi

}


publish_state_api() {
	L_FORCE_UPDATE="$1"
	RESPONSE_TMP="$( call_api ${VAR_API_STATE})"
	#echo " CONTENT OF RESPONSE: ${RESPONSE_TMP}"
	RESPONSE="$( echo "${RESPONSE_TMP}" | jq --tab -f jq_filter_state.txt)"
	#echo " CONTENT OF RESPONSE: ${RESPONSE}" >&2

	# ==== NODES SUBTREE ====
	JSON_NODES_SUBTREE="$( echo "${RESPONSE}" | jq --tab [.nodes[]] )"

	ALL_NODES_ID="$( echo "${JSON_NODES_SUBTREE}" | jq --tab ".[] | .id" )"
	#echo "debug  ALL_NODES_ID = ${ALL_NODES_ID}" >&2

	for L_NODE_ID in ${ALL_NODES_ID} ; do
		echo "processing node ${L_NODE_ID}" 
		NODE_JSON="$( echo "${JSON_NODES_SUBTREE}" | jq --tab ".[] | select( .id == ${L_NODE_ID})" )" 
		L_NODE_NAME="$( echo "${NODE_JSON}" | jq .name | sed "s/\"//g" )" 
		L_SENSOR_PREFIX="pulse_node_${L_NODE_NAME}Z"

		L_DEVICE_JSON=" \"device\":{ \"identifiers\":[ \"pulse_node_${L_NODE_NAME}\" ], \"name\":\"Pulse Node ${L_NODE_NAME}\" }"


		publish_mqtt_ha_config_gen	"sensor" ${L_SENSOR_PREFIX} "name" "{{value_json.name}}" "Name" "${L_DEVICE_JSON}" 
		publish_mqtt_ha_config_gen	"sensor" ${L_SENSOR_PREFIX} "status" "{{value_json.status}}" "Status" "${L_DEVICE_JSON}" 
		publish_mqtt_ha_config_gen	"sensor_measure" ${L_SENSOR_PREFIX} "cpu" "{{value_json.cpu}}" "Cpu" "${L_DEVICE_JSON}" 
		publish_mqtt_pulse_topic 	${L_SENSOR_PREFIX} "${NODE_JSON}"
	done

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
      mqtt_host=*)      VAR_MQTT_HOST="${arg#*=}" ;;
      mqtt_port=*)      VAR_MQTT_PORT="${arg#*=}" ;;
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
while [ $ÃL_CONTINUE} ] 
do
	echo "===== MAIN_LOOP_BEGIN ${LOOP_CPT}" >&2
	if [ "$((LOOP_CPT%60))" -eq  0 ] ;
	then
		# publish data and update HA automatic discovery
		echo "publish_version_api yes"
		publish_version_api yes
	else
		if [ "$((LOOP_CPT%10))" -eq  0 ] ;
		then
			#only push data 
			echo "publish_version_api no"
			publish_version_api no
		fi
	fi
		
	if [ "$(((LOOP_CPT+5)%60))" -eq  0 ] ;
	then
		echo "publish_state_api yes"
		publish_state_api yes

	else
		if [ "$(((LOOP_CPT+5)%10))" -eq  0 ] ;
		then
			#only push data 
			echo "publish_state_api no"
			publish_state_api no
		fi

	fi


	LOOP_CPT=$((LOOP_CPT+1))
	LOOP_CPT=$((LOOP_CPT%300))
	sleep 1
done
exit 0 



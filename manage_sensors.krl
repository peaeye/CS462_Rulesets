ruleset manage_sensors {
	meta {
		name "Manage Sensors"
		description <<
A ruleset to manage the creation and set up of new sensors
		>>
		author "Jack Chen"
		use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
		use module sensor_profile alias profile
    	use module twilio_api_ruleset alias sdk
      		with
        		account_sid = meta:rulesetConfig{"account_sid"}
        		auth_token = meta:rulesetConfig{"auth_token"}
		shares showChildren, getAllChildrenTemperatures, getSensorsSubs
		provides showChildren, getAllChildrenTemperatures, getSensorsSubs
    }
  
   
	global {
		account_sid = meta:rulesetConfig{"account_sid"}
		auth_token = meta:rulesetConfig{"auth_token"}
		from_number = 18304901337
		showChildren = function() {
			ent:sensors
		}
		getSensorsSubs = function() {
			subs:established("Tx_role", "sensor")
		}
		getAllChildrenTemperatures = function() {
			getSensorsSubs().map(function(sub) {
				eci = sub["Tx"];
      			host = sub["Tx_host"].defaultsTo("http://localhost:3000");
				url = host + "/sky/cloud/" + eci + "/temperature_store/temperatures";
     	 		response = http:get(url,{});
      			answer = response{"content"}.decode();
      			return answer
			})
		}
	}

	rule initialize_sensors {
		select when sensor initialize_sensors
		always {
			ent:sensors := {}
		}
	}

	rule new_sensor {
		select when sensor new_sensor
		pre {
			sensor_name = event:attr("sensor_name")
			exists = ent:sensors && ent:sensors >< sensor_name
		}
		if not exists then
			send_directive("creating new sensor pico", {"sensor_name":sensor_name})
		fired {
			raise wrangler event "new_child_request"
				attributes { "name": sensor_name,
					"sensor_name": sensor_name,
					"backgroundColor": "#ff69b4" }
		}
	}

	rule store_new_sensor {
		select when wrangler new_child_created
		pre {
			sensor_eci = {"eci": event:attr("eci")}.klog("CHILD SENSOR ECI:")
 			sensor_name = event:attr("sensor_name").klog("CHILD SENSOR NAME:")
		}
		if sensor_name.klog("found sensor name:") then 
			every {
				event:send(
					{ "eci": sensor_eci.get("eci"), 
					"eid": "install-ruleset", // can be anything, used for correlation
					"domain": "wrangler", "type": "install_ruleset_request",
					"attrs": {
							"absoluteURL": meta:rulesetURI,
							"rid": "temperature_store",
							"config": {},
							"sensor_name": sensor_name
						}
					}
				)
				event:send(
					{ "eci": sensor_eci.get("eci"), 
					"eid": "install-ruleset", // can be anything, used for correlation
					"domain": "wrangler", "type": "install_ruleset_request",
					"attrs": {
							"absoluteURL": meta:rulesetURI,
							"rid": "sensor_profile",
							"config": {},
							"sensor_name": sensor_name
						}
					}
				)
				event:send(
					{ "eci": sensor_eci.get("eci"), 
					"eid": "install-ruleset", // can be anything, used for correlation
					"domain": "wrangler", "type": "install_ruleset_request",
					"attrs": {
							"absoluteURL": meta:rulesetURI,
							"rid": "twilio_api_ruleset",
							"config": {},
							"sensor_name": sensor_name
						}
					}
				)
				event:send(
					{ "eci": sensor_eci.get("eci"), 
					"eid": "install-ruleset", // can be anything, used for correlation
					"domain": "wrangler", "type": "install_ruleset_request",
					"attrs": {
							"absoluteURL": meta:rulesetURI,
							"rid": "simulate_sensor",
							"config": {},
							"sensor_name": sensor_name
						}
					}
				)
				event:send(
					{ "eci": sensor_eci.get("eci"), 
					"eid": "install-ruleset", // can be anything, used for correlation
					"domain": "wrangler", "type": "install_ruleset_request",
					"attrs": {
							"absoluteURL": meta:rulesetURI,
							"rid": "relate_parent_child",
							"config": {},
							"sensor_name": sensor_name
						}
					}
				)
				event:send(
					{ "eci": sensor_eci.get("eci"), 
					"eid": "install-ruleset", // can be anything, used for correlation
					"domain": "wrangler", "type": "install_ruleset_request",
					"attrs": {
							"absoluteURL": meta:rulesetURI,
							"rid": "wovyn_base",
							"config": {"account_sid":account_sid,"auth_token":auth_token},
							"sensor_name": sensor_name
						}
					}
				)
				event:send(
					{ "eci": sensor_eci.get("eci"), 
					"eid": "install-ruleset", // can be anything, used for correlation
					"domain": "sensor", "type": "profile_updated",
					"attrs": {
							"temperature_threshold": ent:default_threshold.defaultsTo(100),
							"to_number": 19255480666,
							"location": "USA",
							"sensor_name": sensor_name
						}
					}
				)
			}
		fired {
			ent:sensors{sensor_name} := sensor_eci
		}
	}

	rule store_new_sensor_subscription {
		select when wrangler subscription_added
		pre {
			name = event:attr("name").klog("name: ")
			tx_role = event:attr("bus")["Tx_role"].klog("tx role: ")
			tx = event:attr("bus")["Tx"].klog("tx: ")
		}
		if tx_role == "sensor" then 
			noop()
		fired{
			ent:sensor_subs{tx} := name
		}
	}

	rule store_external_sensor_subscription {
		select when sensor external_sensor_sub
		pre {
			tx = event:attr("Tx")
			name = event:attr("name")
			host = event:attr("Tx_host")
		}
		always {
    		raise wrangler event "subscription"
        		attributes {
        			"wellKnown_Tx" : tx,
          			"name" : name,
          			"Rx_role": "peer_sensor_collection",
          			"Tx_role": "sensor",
          			"channel_type": "subscription",
          			"Tx_host": host
        		}
    	}
	}

	rule unneeded_sensor {
		select when sensor unneeded_sensor
		pre {
			sensor_name = event:attr("sensor_name")
			exists = ent:sensors >< sensor_name
			eci_to_delete = ent:sensors{[sensor_name,"eci"]}
			Id = ent:sensor_subs.filter(function(k,v){v == sensor_name+"-sensor"}).keys().head().klog("Id")
		}
		if exists && eci_to_delete then
			send_directive("deleting_sensor", {"sensor_name":sensor_name})
		fired {
			raise wrangler event "child_deletion_request"
				attributes {"eci": eci_to_delete};
			raise wrangler event "subscription_cancellation"
        		attributes {"Id":Id}
			clear ent:sensors{sensor_name}
		}
	}

	rule threshold_notification {
		select when sensor threshold_violation

		pre {
			temp = event:attrs{"temperature"}
		}

		every {
        	sdk:sendMessage(profile:get_to_number(), from_number, "temperature threshold has been breached") setting(response)
			send_directive("message sent from manage_sensors",{"response":response})
		}
	}
}

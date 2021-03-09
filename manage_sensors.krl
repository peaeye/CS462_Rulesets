ruleset manage_sensors {
	meta {
		name "Manage Sensors"
		description <<
A ruleset to manage the creation and set up of new sensors
		>>
		author "Jack Chen"
		use module io.picolabs.wrangler alias wrangler
		shares showChildren, getAllChildrenTemperatures
		provides showChildren, getAllChildrenTemperatures
    	}
  
   
	global {
		showChildren = function() {
			ent:sensors
		}
		getAllChildrenTemperatures = function() {
			ent:sensors.map(function(v,k) {wrangler:picoQuery(v{"eci"}, "temperature_store", "temperatures", {});})
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
			sensor_eci = {"eci": event:attr("eci")}
 			sensor_name = event:attr("sensor_name")
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
							"rid": "wovyn_base",
							"config": {"account_sid":"AC7dfb42b05d1554a116e1e7a890600bfd","auth_token":"8f02606e791f1101b873e580777aa733"},
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

	rule unneeded_sensor {
		select when sensor unneeded_sensor
		pre {
			sensor_name = event:attr("sensor_name")
			exists = ent:sensors >< sensor_name
			eci_to_delete = ent:sensors{[sensor_name,"eci"]}
		}
		if exists && eci_to_delete then
			send_directive("deleting_sensor", {"sensor_name":sensor_name})
		fired {
			raise wrangler event "child_deletion_request"
				attributes {"eci": eci_to_delete};
			clear ent:sensor_name{sensor_name}
		}
	}
}

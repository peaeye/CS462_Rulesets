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
		shares showChildren, getAllChildrenTemperatures, getSensorsSubs, genCorrelationNumber, getReports, getRecentReports
		provides getSensorsSubs, genCorrelationNumber
    }
  
   
	global {
		/*****************************************************
        *  GLOBAL VARIABLES
        */
		account_sid = meta:rulesetConfig{"account_sid"}
		auth_token = meta:rulesetConfig{"auth_token"}
		from_number = 18304901337
		
        /*****************************************************
        *  FUNCTIONS
        */
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
		genCorrelationNumber = function() {
			wrangler:myself(){"eci"} + time:now()
		}
		getReports = function(){
			ent:sensor_reports
		}
		getRecentReports = function(){
			num_reports = ent:sensor_reports.length();
			limit = ((num_reports > 5) => 5 | num_reports).klog("limit:");
			keys = ent:sensor_reports.keys().sort().klog("keys:");

			recent_keys = keys.slice(num_reports-limit, num_reports-1).klog("keys:")

			recent_keys.map(function(x) {
				{}.put(x,ent:sensor_reports.get(x));
			})
			
		}
	}

	rule initialize_sensors {
		select when sensor_manager initialize_sensors
		always {
			ent:sensors := {}
		}
	}

	rule new_sensor {
		select when sensor_manager new_sensor
		pre {
			sensor_name = event:attrs{"sensor_name"}
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
			sensor_eci = {"eci": event:attrs{"eci"}}.klog("CHILD SENSOR ECI:")
 			sensor_name = event:attrs{"sensor_name"}.klog("CHILD SENSOR NAME:")
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
			name = event:attrs{"name"}.klog("name: ")
			tx_role = event:attrs{"bus"}["Tx_role"].klog("tx role: ")
			tx = event:attrs{"bus"}["Tx"].klog("tx: ")
		}
		if tx_role == "sensor" then 
			noop()
		fired{
			ent:sensor_subs{tx} := name
		}
	}

	rule store_external_sensor_subscription {
		select when sensor_manager external_sensor_sub
		pre {
			tx = event:attrs{"Tx"}
			name = event:attrs{"name"}
			host = event:attrs{"Tx_host"}
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
		select when sensor_manager unneeded_sensor
		pre {
			sensor_name = event:attrs{"sensor_name"}
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

	rule clear_reports {
		select when sensor_manager clear_reports
		send_directive("Clearing the reports entity variable")
		fired {
			ent:sensor_reports := {}
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

	rule start_periodic_report {
		select when sensor_manager periodic_report
		pre {
			new_rcn = genCorrelationNumber()
			rcn = event:attrs{"report_correlation_number"}.klog("report corrl number:") || new_rcn.klog("new_rcn:")
			num_sensors = getSensorsSubs().length().klog("num_sensors length:")
			augmented_attrs = event:attrs
								.put(["report_correlation_number"], rcn)
		}
		send_directive("Creating new report with rcn:" + rcn)
		fired {
			raise explicit event "periodic_report_routable"
				attributes augmented_attrs
			ent:sensor_reports{[rcn, "temperature_sensors"]} := num_sensors
			ent:sensor_reports{[rcn, "responding"]} := 0
			schedule explicit event "periodic_report_timer_expired"
				at time:add(time:now(),{"minutes" : 2}) 
				attributes {"report_correlation_number": rcn}
		  }
	}

	rule process_periodic_report_with_rcn {
		select when explicit periodic_report_routable
		foreach getSensorsSubs() setting(sub)
		pre {
			rcn = event:attrs{"report_correlation_number"}.klog("rcn:")
			channel = sub["Tx"].klog("channel:")
		}
		if(not rcn.isnull()) then 
			event:send({"eci":channel,
						"domain":"sensor", "name":"periodic_sensor_report",
						"attrs": {
							"report_correlation_number": rcn,
							"sensor_id": sub{"Tx"},
						}
			})
	}

	rule catch_periodic_vehicle_reports {
		select when sensor_manager periodic_sensor_report_created
	  
		pre {
			wellKnown_Rx = event:attrs{"wellKnown_Rx"}.klog("wellKnown_Rx:")
			rcn = event:attrs{"report_correlation_number"}.klog("rcn:")
			updated_sensor_reports =
				(ent:sensor_reports{[rcn,"reports"]})
					.defaultsTo([])
					.append(event:attrs{"temperature_details"}.decode().put(["Rx_id"], wellKnown_Rx)).klog("updated_sensor_reports:")
			responding = ent:sensor_reports{[rcn,"responding"]}
	  
		}
		noop();
		always {
			ent:sensor_reports{[rcn,"reports"]} := updated_sensor_reports
			ent:sensor_reports{[rcn,"responding"]} := responding + 1
			raise explicit event "periodic_sensor_report_added"
				attributes {"rcn": rcn}
		}
	}

	rule check_periodic_report_status {
		select when explicit periodic_sensor_report_added
		pre {
			rcn = event:attrs{"rcn"}.klog("rcn:")
			num_sensors = ent:sensor_reports{[rcn,"temperature_sensors"]}.klog("num_sensors:")
			num_reports_received = ent:sensor_reports{[rcn,"responding"]}.klog("num_reports_received:")
		}
		if ( num_sensors <= num_reports_received ) then noop();
		fired {
			log info "process sensor reports "
		/*
		  raise explicit event "periodic_report_ready" with
			report_correlation_number = rcn;
		*/
		} else {
		 	log info "we're still waiting for " +
				(num_sensors - num_reports_received) +
				" reports on #{rcn}"
		}
	} 
}

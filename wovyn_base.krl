ruleset wovyn_base {
 	meta {
    	name "Wovyn Base"
    	description <<
A base ruleset for wovyn
		>>
    	author "Jack Chen"
        use module io.picolabs.subscription alias subs
    	use module sensor_profile alias profile
		use module relate_parent_child alias relation
    	use module twilio_api_ruleset alias sdk
      		with
        		account_sid = meta:rulesetConfig{"account_sid"}
        		auth_token = meta:rulesetConfig{"auth_token"}
	}
   
	global {
		temperature_threshold = profile:get_temperature_threshold()
		violation_number = profile:get_to_number()
		from_number = 18304901337
	}

	rule new_testing_temperature {
		select when wovyn test
		pre {
			temperature_value = event:attrs{"temperature_value"}.klog("TEMP VALUE: ")
			timestamp = event:attrs{"timestamp"}.klog("TIME VALUE:")

			temperature = [
				{
				  "name": "testing temperature",
				  "transducerGUID": "testing transducerGUID",
				  "units": "degrees",
				  "temperatureF": temperature_value,
				  "temperatureC": (temperature_value - 32)/ 180 
				}
			]
			obj = {"temperature": temperature, "timestamp": timestamp}
		}
		send_directive("Creating new Test Temperature", obj)
		fired {
			raise wovyn event "new_temperature_reading"
				attributes obj
		}
	}

	rule process_heartbeat {
		select when wovyn heartbeat
		pre {
		  	thing = event:attrs{"genericThing"}.klog("GENERIC VALUE: ")
			temperatureF = event:attrs{["genericThing", "data", "temperature"]}.klog("TempF VALUE:")
		}	
		if (thing) then
		every {
    				send_directive("wovyn", {"heartbeat": thing})
		}

		fired {
			raise wovyn event "new_temperature_reading"
				attributes {"temperature": event:attrs{["genericThing", "data", "temperature"]}, "timestamp": time:now()}
		}
		else {
			
		}
  	}

	rule find_high_temps {
		select when wovyn new_temperature_reading
		pre {
			temperatureA = event:attrs{"temperature"}.klog("tempA:")
			tempB = temperatureA[0].klog("tempB")
			tempF = tempB{"temperatureF"}.klog("tempF")

		}
		if tempF > profile:get_temperature_threshold().klog("Temp Thresh") then send_directive("high temp breached", {"temp" : tempF})
		fired {
			raise wovyn event "threshold_violation" attributes {"temperature": temperatureA, "timestamp": event:attrs{"timestamp"}}
		}
	}

	rule threshold_notification {
		select when wovyn threshold_violation

		pre {
			temp = event:attrs{"temperature"}
		}

		every {
        	//sdk:sendMessage(profile:get_to_number(), from_number, "temperature threshold has been breached") setting(response)
			//send_directive("message sent",{"response":response})
			event:send({"eci":relation:getSubscriptionTx().klog("subsTX:"),
				"domain":"sensor", "name":"threshold_violation",
				"attrs":{
					"wellKnown_Tx":subs:wellKnown_Rx(){"id"},
					"temperature":temp,
					"name":ent:name
				}
			})
		}
	}
}

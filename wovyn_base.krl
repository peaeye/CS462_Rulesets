ruleset wovyn_base {
  meta {
    name "Wovyn Base"
    description <<
A base ruleset for wovyn
>>
    author "Jack Chen"
    use module twilio_api_ruleset alias sdk
      with
        account_sid = meta:rulesetConfig{"account_sid"}
        auth_token = meta:rulesetConfig{"auth_token"}
  }
   
	global {
		temperature_threshold = 160
		violation_number = 19255480666
		from_number = 18304901337
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
		if tempF > temperature_threshold then send_directive("high temp breached", {"temp" : tempF})
		fired {
			raise wovyn event "threshold_violation" attributes {"temperature": temperatureA, "timestamp": event:attrs{"timestamp"}}
		}
	}

	rule threshold_notification {
		select when wovyn threshold_violation

		every{
        		sdk:sendMessage(violation_number, from_number, "temperature threshold has been breached") setting(response)
			send_directive("message sent",{"response":response})
		}
	}
}

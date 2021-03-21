ruleset temperature_store {
	meta {
		name "Temperature Store"
		description <<
A persistant data store for the temperature
		>>
		author "Jack Chen"
		use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
		shares temperatures, temperature_violations, inrange_temperatures
		provides temperatures, temperature_violations, inrange_temperatures
    	}
  
   
	global {
		temperatures = function() {
			ent:tempsVar
		}
		temperature_violations = function() {
			ent:tempViolationsVar
		}
		inrange_temperatures = function() {
			ent:tempsVar.filter(function(x){ent:tempViolationsVar.index(x) < 0})
		}
	}

	rule collect_temperatures {
    		select when wovyn new_temperature_reading
	    	pre {
		  	temperature = event:attrs{"temperature"}.klog("TEMP VALUE: ")
			timestamp = event:attrs{"timestamp"}.klog("TIME VALUE:")
		}	
		send_directive("collect_temperatures", {"temperature": temperature, "timestamp": timestamp})

		fired {
			ent:tempsVar := ent:tempsVar => ent:tempsVar.append({"temperature": temperature, "timestamp": timestamp}) | 
											[{"temperature": temperature, "timestamp": timestamp}]
		}
  	}

	rule collect_threshold_violations {
		select when wovyn threshold_violation
		pre {
		  	temperature = event:attrs{"temperature"}.klog("TEMP VALUE: ")
			timestamp = event:attrs{"timestamp"}.klog("TIME VALUE:")
		}
		send_directive("collect_threshold_violations", {"temperature": temperature, "timestamp": timestamp})

		fired {
			ent:tempViolationsVar := ent:tempViolationsVar => ent:tempViolationsVar.append({"temperature": temperature, "timestamp": timestamp}) | 
											[{"temperature": temperature, "timestamp": timestamp}]
		}
	}

	rule collect_most_recent_temperature {
		select when sensor periodic_sensor_report
		pre {
			rcn = event:attrs{"report_correlation_number"}.klog("report_correlation_number:")
			sensor_id = event:attrs{"sensor_id"}.klog("sensor_id:")
			latestTemp = temperatures()[temperatures().length()-1]
		}
		//send_directive({"latest temp": latestTemp})
		event:send({"eci":wrangler:parent_eci(),
					"domain":"sensor_manager", "name":"periodic_sensor_report_created",
					"attrs": {
						"wellKnown_Rx":subs:wellKnown_Rx(){"id"},
						"report_correlation_number":rcn,
						"temperature_details":latestTemp
					}
		})
	}

	rule clear_temperatures {
		select when wovyn reading_reset
		
		send_directive("clear_temperatures", {})

		fired {
			ent:tempViolationsVar := []
			ent:tempsVar := []
		}
	}
}

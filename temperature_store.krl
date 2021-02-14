ruleset temperature_store {
	meta {
		name "Temperature Store"
		description <<
A persistant data store for the temperature
		>>
		author "Jack Chen"
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

	rule clear_temperatures {
		select when wovyn reading_reset
		
		send_directive("clear_temperatures", {})

		fired {
			clear ent:tempViolationsVar
			clear ent:tempsVar
		}
	}
}

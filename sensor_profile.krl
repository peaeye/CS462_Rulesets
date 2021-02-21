ruleset sensor_profile {
	meta {
		name "Sensor Profile"
		description <<
A sensor profile
		>>
		author "Jack Chen"
		shares get_temperature_threshold, get_to_number, get_sensor_location, get_sensor_name
		provides get_temperature_threshold, get_to_number, get_sensor_location, get_sensor_name
    	}
  
   
	global {
		get_temperature_threshold = function() {
			ent:temperature_threshold
		}
		get_to_number = function() {
			ent:to_number
		}
		get_sensor_location = function() {
			ent:sensor_location
		}
		get_sensor_name = function() {
			ent:sensor_name
		}
	}

	rule initialize_ruleset {
		select when wrangler ruleset_installed
		pre {
			
		}
		send_directive("Initialized Sensor Ruleset")
		always {
			ent:sensor_location := "Pleasanton"
			ent:sensor_name := "Wovyn Sensor"
			ent:temperature_threshold := 100
			ent:to_number := 9255480666
		}
	}

	rule update_profile {
    		select when sensor profile_updated
	    	pre {
			location = event:attrs{"location"}.klog("Location:") || ent:sensor_location
			name = event:attrs{"sensor_name"}.klog("Sensor Name:") || ent:sensor_name
			
			threshold = event:attrs{"temperature_threshold"}.decode().klog("Threshold:") || ent:temperature_threshold
			number = event:attrs{"to_number"}.decode().klog("New number:") || ent:to_number
		}	
		send_directive("Profile Updated", {"location": location, "name": name, "threshold": threshold, "number": number})

		fired {
			ent:sensor_location := location
			ent:sensor_name := name
			ent:temperature_threshold := threshold
			ent:to_number := number
		}
  	}
}

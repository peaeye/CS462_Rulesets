ruleset relate_parent_child {
	meta {
		name "Establish a Parent Child relationship"
		description <<
A ruleset to establish a parent child relationship
		>>
		author "Jack Chen"
		use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        provides getSubscriptionTx
    }
  
   
	global {
        tags = ["relate_parent_child"]
        eventPolicy = {
            "allow": [ { "domain": "sensor", "name": "*" }, ],
            "deny": []
        }
        queryPolicy = {
            "allow": [ { "rid": meta:rid, "name": "*" } ],
            "deny": []
        }
        getSubscriptionTx = function() {
            ent:subscriptionTx
        }
	}

    rule pico_ruleset_added {
        select when wrangler ruleset_installed 
            where event:attr("rids") >< meta:rid
        pre {
            rids = event:attrs{"rid"}.klog("RIDS")
            meta_rid = meta:rid.klog("META RID")
            boolean = (event:attr("rids") >< meta:rid).klog("TRUTH VALUE")
            sensor_name = event:attrs{"sensor_name"}.klog("SENSOR NAME:")
            parent_eci = wrangler:parent_eci().klog("PARENT ECI:")
            wellKnown_eci = subs:wellKnown_Rx(){"id"}.klog("WELLKNOWN ECI NAME:")
        }
        if ent:sensor_eci.isnull() then
            wrangler:createChannel(tags,eventPolicy,queryPolicy) setting(channel)
        /*
        event:send({"eci":parent_eci,
            "domain": "sensor", "type": "new_subscription",
            "attrs": {
                "sensor_name": sensor_name,
                "wellKnown_eci": wellKnown_eci
            }
        })*/
        fired {
            ent:name := sensor_name
            ent:sensor_name := sensor_name
            ent:parent_eci := parent_eci
            ent:wellKnown_Rx := wellKnown_eci
            ent:student_eci := channel{"id"}
            raise sensor event "new_subscription_request"
        }
    }

    rule make_a_subscription {
        select when sensor new_subscription_request
        event:send({"eci":ent:parent_eci,
            "domain":"wrangler", "name":"subscription",
            "attrs": {
                "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
                "Rx_role":"sensor_collection", "Tx_role":"sensor",
                "name":ent:name+"-sensor", "channel_type":"subscription"
            }
        })
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            my_role = event:attr("Rx_role")
            their_role = event:attr("Tx_role")
        }
        if my_role=="sensor" && their_role=="sensor_collection" then noop()
        fired {
            raise wrangler event "pending_subscription_approval"
                attributes event:attrs
            ent:subscriptionTx := event:attr("Tx")
        } else {
            raise wrangler event "inbound_rejection"
            attributes event:attrs
        }
    }
}

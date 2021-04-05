ruleset gossip_protocol {
    meta {
        name "Gossip Protocol"
		description "Allow sensors to spread their stored temperatures to other sensors to create a consistent state"
		author "Jack Chen"
        
		use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        shares getTemperatures, getRumorsReceived, getSeenMessagesByTx, getCurrentSeenSoFar, getSensorInfo
    }

    global {
        /*****************************************************
        *  GLOBAL VARIABLES
        */

        /*****************************************************
        *  FUNCTIONS
        */

        /**
            Read-only functions to display the state of the pico's persistent variables
        */
        getTemperatures = function() {
            ent:rumors_received.map(function(x) {
                {
                    "F": x{"Temperature"}[0]{"temperatureF"},
                    "time": x{"Timestamp"}
                }
            })
        }
        getRumorsReceived = function() {
            ent:rumors_received
        }
        getSeenMessagesByTx = function() {
            ent:seen_messages_by_tx
        }
        getCurrentSeenSoFar = function() {
            ent:current_seen_so_far
        }
        getSensorInfo = function() {
            {
                "uuid": ent:uuid,
                "current_sequence": ent:current_sequence,
                "protocol_on": ent:protocol_on,
                "timeBetweenHeartbeats": ent:timeBetweenHeartbeats,
                "nextHeartbeat": schedule:list()
                /*.map(function(x) {
                    x{"time"}
                })*/
            }
        }

        /**
            General, assorted helper functions
        */
        generateUUID = function() {
            random:uuid()
        }
        getSequenceNumberInMessage = function(message_id){
            splits = message_id.split(re#:#)
            splits[splits.length()-1].as("Number")
        }


        /**
            Get a Peer from our list of peers to send a message to + helper functions
        */
        getNodes = function() {
            subs:established("Tx_role", "node")
        }
        getPeer = function() {
            subs = subs:established("Tx_role", "node")

            subs_with_missing_rumors = subs.filter(function(x) {
                wellKnown_tx = x{"Tx"};
                getMissingRumors(x{"Tx"}).length() > 0
            }).klog("subs with missing rumors:")

            rand_int = subs_with_missing_rumors.length() > 0 
                        => random:integer(subs_with_missing_rumors.length()-1) | -1
            
            sub = (rand_int == -1) => subs[random:integer(subs.length()-1)] | subs_with_missing_rumors[rand_int]
            sub
        }

        /**
            Randomly create a rumor or seen message for sending + helper functions
        */
        prepareMessage = function(sub) {
            is_rumor_message = random:integer(10) < 7 => true | false
            message = is_rumor_message => prepareRumor(sub) | prepareSeen(sub)
            message
        }
        prepareRumor = function(sub) {
            // missed_rumors is the list of all rumors that the target sub is missing
            missed_rumors = getMissingRumors(sub{"Tx"})

            // if the target sub isn't missing any rumors, just send a seen message
            rumor_message = (missed_rumors.length() < 1) => prepareSeen(sub)
                                | { "message":  missed_rumors[0],
                                    "type": "rumor" }
            rumor_message
        }
        getMissingRumors = function(node) {
            // node is the tx of the pico we are trying to send a message to

            // seen_message is the most recent seen message sent by the subscription
            seen_message = ent:seen_messages_by_tx{node}
            // find all rumors that the node has missed
            missed_rumors = ent:rumors_received.filter(function(v) {
                messageID = v{"MessageID"};
                sensorID = v{"SensorID"};
                seen_message{sensorID}.isnull() || (seen_message{sensorID} < getSequenceNumberInMessage(messageID))
            })

            // sort the list of missed rumors such that the earliest sequentially missed rumor comes first
            sorted_missed_rumors = missed_rumors.sort(function(a,b) {
                aSeqNum = getSequenceNumberInMessage(a{"MessageID"});
                bSeqNum = getSequenceNumberInMessage(b{"MessageID"});
                aSeqNum <=> bSeqNum
            }) 
            sorted_missed_rumors
        }
        prepareSeen = function(sub) {
            seen_message = {"message": ent:current_seen_so_far, 
                            "sender": sub,
                            "type": "seen"}
            seen_message
        }

        /**
            Find the highest sequence number that can be reached without skipping any sequences
        */
        getBestSequenceSoFar = function(sensor_id) {
            // get all rumors from received rumors that correspond to the sensor that we got the rumor message from
            sensor_rumors = ent:rumors_received.filter(function(x) {
                id = x{"SensorID"}
                id == sensor_id
            }).klog("sensor_rumors:")
            // sort the rumors in ascending order
            sorted = sensor_rumors.sort(function(a,b) {
                aSeqNum = getSequenceNumberInMessage(a{"MessageID"});
                bSeqNum = getSequenceNumberInMessage(b{"MessageID"});
                aSeqNum <=> bSeqNum
            }).klog("sorted:").map(function(x) {
                getSequenceNumberInMessage(x{"MessageID"});
            })

            best_seq = (sorted.length() == 0) => 0 | sorted.reduce(function(a,b) {
                (b == a + 1) => b | a
            }, -1).klog("reduced:")
            best_seq
        }

        /**
            Create a new rumor based on a new temperature reading
        */
        create_new_rumor = function(temp, time) {
            {
                "MessageID": ent:uuid + ":" + ent:current_sequence,
                "SensorID": ent:uuid,
                "Temperature": temp,
                "Timestamp": time
              }
        }

    }

    rule pico_ruleset_added {
        select when wrangler ruleset_installed
            where event:attr("rids") >< meta:rid
        /**
            Initialize the ruleset with entity variables
        */
        pre {
            uuid = generateUUID()
            timeBetweenHeartbeats = event:attrs{"timeBetweenHeartbeats"} || 10
        }
        noop()
        fired {
            ent:uuid := uuid
            ent:current_sequence := 0
            ent:protocol_on := "on"
            ent:timeBetweenHeartbeats := timeBetweenHeartbeats

            ent:rumors_received := []           // all rumors received from other picos
            ent:current_seen_so_far := {}       // map of the latest sequence seen from each SensorID; this is the content of our seen message
            ent:seen_messages_by_tx := {}       // map of all the seen messages received from other picos, keyed by their subscription id
            schedule gossip event "heartbeat" 
                at time:add(time:now(), {"seconds": 10}).klog("Schedule first heartbeat at:")
        }
    }

    rule process_heartbeat {
        select when gossip heartbeat
            where ent:protocol_on == "on"
        pre {
            subscriber = getPeer().klog("Sending Message to:")
            message = prepareMessage(subscriber).klog("Message Contents:")
            message_id = message{"MessageID"}
            sensor_id = message{"SensorID"}
        }
        if subscriber.isnull() == false && message.isnull() == false then
        every {
            event:send({
                "eci": subscriber{"Tx"},
                "domain": "gossip", "name": message{"type"},
                "attrs": message
            })
            send_directive("Sending message", {"type": message{"type"}, "message_contents": message{"message"}})
        }
            

        fired {
            ent:seen_messages_by_tx{[subscriber{"Tx"}, sensor_id]} := getSequenceNumberInMessage(message_id)
                if message{"type"} == "rumor" &&
                    ((ent:seen_messages_by_tx{[subscriber{"Tx"}, sensor_id]}.isnull() && getSequenceNumberInMessage(message_id) == 0) || 
                    ent:seen_messages_by_tx{[subscriber{"Tx"}, sensor_id]} + 1 == getSequenceNumberInMessage(message_id))
        }
        finally {
            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:timeBetweenHeartbeats}).klog("Schedule new heartbeat at:")
                if ent:protocol_on == "on" && schedule:list().none(function(x) {
                    x{["event", "domain"]} == "gossip" && x{["event", "name"]} == "heartbeat"
                })
        }
    }

    rule turn_protocol_on_or_off {
        select when gossip process
        pre {
            status = event:attrs{"status"}
        }
        if status.isnull() || (status != "on" && status != "off") 
            then send_directive("Turning the protocol", (ent:protocol_on == "on") => "off" | "on")
        fired {
            ent:protocol_on := (ent:protocol_on == "on") => "off" | "on"
        }
        else {
            ent:protocol_on := status
        }
        finally {
            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:timeBetweenHeartbeats}).klog("Schedule new heartbeat at:")
                if ent:protocol_on == "on" && schedule:list().none(function(x) {
                    x{["event", "domain"]} == "gossip" && x{["event", "name"]} == "heartbeat"
                })
            raise gossip event "reset_schedule"
                if ent:protocol_on == "on" && schedule:list().any(function(x) {
                    x{["event", "domain"]} == "gossip" && x{["event", "name"]} == "heartbeat"
                })
        }
    }

    rule catch_rumor_message {
        select when gossip rumor
            where ent:protocol_on == "on"
        pre {
            message = event:attrs{"message"}
            message_id = message{"MessageID"}
            sensor_id = message{"SensorID"}
            sequence_num = getSequenceNumberInMessage(message_id)
        }
        if ent:current_seen_so_far{sensor_id}.isnull() then noop()
        fired {
            ent:current_seen_so_far{sensor_id} := -1
        }
        finally {
            ent:rumors_received := ent:rumors_received.none(function(x){x{"MessageID"} == message_id }) =>
                            ent:rumors_received.append(message) | ent:rumors_received
            ent:current_seen_so_far{sensor_id} := getBestSequenceSoFar(sensor_id)
        }
    }

    rule catch_seen_message {
        select when gossip seen
            where ent:protocol_on == "on"
        pre {
            message = event:attrs{"message"}
            sender = event:attrs{["sender", "Rx"]}
        }
        noop()
        fired {
            ent:seen_messages_by_tx{sender} := message
        }
    }

    rule store_new_node_subscription {
        select when wrangler subscription_added
        pre {
			name = event:attrs{"name"}.klog("name: ")
			tx_role = event:attrs{"bus"}["Tx_role"].klog("tx role: ")
			tx = event:attrs{"bus"}["Tx"].klog("tx: ")
		}
		if tx_role == "node" then 
			noop()
		fired{
			ent:seen_messages_by_tx{tx} := {}
		}
    }

    rule new_local_temperature{
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}.klog("TEMP VALUE: ")
            timestamp = event:attrs{"timestamp"}.klog("TIME VALUE:")
            message = create_new_rumor(temperature, timestamp)
        }
        noop()
        fired {
            ent:current_sequence := (ent:current_sequence + 1).klog("success1")
            ent:rumors_received := ent:rumors_received.append(message).klog("success2")
            ent:current_seen_so_far{ent:uuid} := getBestSequenceSoFar(ent:uuid).klog("success3")
        }
    }

    rule reset_schedule {
        select when gossip reset_schedule
        foreach schedule:list() setting(x)
        pre {
            id = x{"id"}
        }
        schedule:remove(id)
        fired {
            schedule gossip event "heartbeat" 
                at time:add(time:now(), {"seconds": 10}).klog("Schedule reset heartbeat at:")
        }
    }
}
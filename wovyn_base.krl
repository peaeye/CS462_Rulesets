ruleset wovyn_base {
  meta {
    name "Wovyn Base"
    description <<
A base ruleset for wovyn
>>
    author "Jack Chen"
  }
   
  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
	  thing = event:attrs{"genericThing"}.klog("GENERIC VALUE: ")
    }
    send_directive("wovyn", {"heartbeat": thing})
  }
 }

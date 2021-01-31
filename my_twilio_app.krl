ruleset my_twilio_app {
  meta {
    name "My Twilio App"
    description <<
Application that uses the Twilio API
>>
    author "Jack Chen"
    use module twilio_api_ruleset alias sdk
      with
        account_sid = meta:rulesetConfig{"account_sid"}
        auth_token = meta:rulesetConfig{"auth_token"}
    shares getMessages
  }

  global {
  	getMessages = function(to, from, pageSize) {
		sdk:messages(to, from, pageSize)
	}
  }

  rule send_message {
	select when message send
        pre {
            to = event:attrs{"to"}.klog("TO VALUE: ")
	    from = event:attrs{"from"}.klog("FROM VALUE: ")
            content = event:attrs{"content"}.klog("BODY VALUE: ")
        }
	every{
        	sdk:sendMessage(to, from, content) setting(response)
		send_directive("message sent",{"response":response})
	}
	fired {
		log debug "RESPONSE: "+response
	}
  }
}

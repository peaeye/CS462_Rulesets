ruleset twilio_api_ruleset {
  meta {
	name "Twilio API"
	description <<
A supporting ruleset to call the Twilio API
>>
	author "Jack Chen"
 	configure using
 		account_sid = ""
		auth_token = ""
 	provides sendMessage, messages
  }

  global {
  	base_url = "https://api.twilio.com"

        sendMessage = defaction(to, from, body) {
		auth = {"username":account_sid, "password":auth_token}
		bodyDict = {"To":to, "From":from, "Body":body}
        	http:post(<<#{base_url}/2010-04-01/Accounts/#{account_sid}/Messages.json>>, auth=auth, form=bodyDict) setting(response)
       		return response
        }

	messages = function(to, from, pageSize) {
		auth = {"username":account_sid, "password":auth_token}
		queryString = {}
		queryString1 = to => queryString.put({"To": to}) | queryString
		queryString2 = from => queryString1.put({"From": from}) | queryString
		queryString3 = pageSize => queryString2.put({"PageSize": pageSize}) | queryString
        	response = http:get(<<#{base_url}/2010-04-01/Accounts/#{account_sid}/Messages.json>>, auth=auth, qs=queryString3)
       		response{"content"}.decode()

	}
  }
}

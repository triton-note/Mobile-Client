.factory 'ServerFactory', ($log, $http, $ionicPopup, serverURL) ->
	url = (path) -> "#{serverURL}/#{path}"
	retryable = (retry, config, res-taker, error-taker) !-> ionic.Platform.ready !->
		$http config
		.success (data, status, headers, config) !-> res-taker data
		.error (data, status, headers, config) !->
			$log.error "Error on request:#{angular.toJson config} => (#{status})#{data}"
			error = http-error.gen status, data
			if error.type == http-error.types.error && retry > 0
			then retryable retry - 1, config, res-taker, error-taker
			else error-taker error
	http = (method, path, data = null, content-type = "text/json") -> (res-taker, error-taker, retry = 3) !->
		retryable retry,
			method: method
			url: url(path)
			data: data
			headers:
				if data
				then 'Content-Type': content-type
				else {}
		, res-taker, error-taker

	http-error =
		types:
			fatal: 'Fatal'
			error: 'Error'
			expired: 'Expired'
		gen: (status, data) -> switch status
		| 400 =>
			if data.indexOf('Expired') > -1 then
				type: @types.expired
				msg: "Token Expired"
			else
				type: @types.Error
				msg: "Application Error"
		| 404 =>
			type: @types.fatal
			msg: "Not Found"
		| 501 =>
			type: @types.fatal
			msg: "Not Implemented"
		| 503 =>
			type: @types.fatal
			msg: "Service Unavailable"
		| _   =>
			type: @types.error
			msg: "Error"

	/*
	Login to Server
	*/
	login: (accessKey, ticket-taker, error-taker) !->
		way = 'facebook'
		$log.debug "Login to server with #{way} by #{accessKey}"
		http('POST', "login/#{way}",
			accessKey: accessKey
		) ticket-taker, error-taker
	/*
	Connect account to social service
	*/
	connect: (ticket, accessKey) -> (success-taker, error-taker) !->
		way = 'facebook'
		$log.debug "Connecting to #{way} by token:#{accessKey}"
		http('POST', "account/connect/#{way}",
			ticket: ticket
			accessKey: accessKey
		) success-taker, error-taker
	/*
	Disconnect account to social service
	*/
	disconnect: (ticket) -> (success-taker, error-taker) !->
		way = 'facebook'
		$log.debug "Disconnecting server from #{way}"
		http('POST', "account/disconnect/#{way}",
			ticket: ticket
		) success-taker, error-taker
	/*
	Get start session by server, then pass to taker
	*/
	start-session: (ticket, geoinfo) -> (session-taker, error-taker) !->
		$log.debug "Starting session by #{ticket} on #{angular.toJson geoinfo}"
		http('POST', "report/new-session",
			ticket: ticket
			geoinfo: geoinfo
		) session-taker, error-taker
	/*
	Put a photo which is encoded by base64 to session
	*/
	put-photo: (session, ...photos) -> (success-taker, error-taker) !->
		$log.debug "Putting a photo with #{session}: #{photos}"
		http('POST', "report/photo",
			session: session
			names: photos
		) success-taker, error-taker
	/*
	Put a photo which is encoded by base64 to session
	*/
	infer-photo: (session) -> (success-taker, error-taker) !->
		$log.debug "Inferring a photo with #{session}"
		http('POST', "report/infer",
			session: session
		) success-taker, error-taker
	/*
	Put given report to the session
	*/
	submit-report: (session, given-report) -> (success, error-taker) !->
		report = angular.copy given-report
		report.dateAt = report.dateAt.getTime!
		$log.debug "Submitting report with #{session}: #{angular.toJson report}"
		http('POST', "report/submit",
			session: session
			report: report
		) success, error-taker
	/*
	Put given report to the session
	*/
	publish-report: (ticket, report-id, accessKey) -> (success, error-taker) !->
		$log.debug "Publishing report(#{report-id}) with #{ticket}: #{accessKey}"
		http('POST', "report/publish/facebook",
			ticket: ticket
			id: report-id
			accessKey: accessKey
		) success, error-taker
	/*
	Load report from server, then pass to taker
	*/
	load-reports: (ticket, count, last-id) -> (taker, error-taker) !->
		$log.debug "Loading #{count} reports from #{last-id}"
		http('POST', "report/load",
			ticket: ticket
			count: count
			last: last-id
		) taker, error-taker
	/*
	*/
	read-report: (ticket, id) -> (taker, error-taker) !->
		$log.debug "Reading report(id:#{id})"
		http('POST', "report/read",
			ticket: ticket
			id: id
		) taker, error-taker
	/*
	Update report to server. ID has to be contain given report.
	*/
	update-report: (ticket, given-report) -> (success, error-taker) !->
		report = angular.copy given-report
		report.dateAt = report.dateAt.getTime!
		$log.debug "Updating report: #{angular.toJson report}"
		http('POST', "report/update",
			ticket: ticket
			report: report
		) success, error-taker
	/*
	Remove report from server
	*/
	remove-report: (ticket, id) -> (success, error-taker) !->
		$log.debug "Removing report(#{id})"
		http('POST', "report/remove",
			ticket: ticket
			id: id
		) success, error-taker
	/*
	Load measures in account settings
	*/
	load-measures: (ticket) -> (success, error-taker) !->
		$log.debug "Loading measures"
		http('POST', "account/measures/load",
			ticket: ticket
		) success, error-taker
	/*
	Update measures in account settings
	*/
	update-measures: (ticket, measures) -> (success, error-taker) !->
		$log.debug "Changing measures: #{angular.toJson measures}"
		http('POST', "account/measures/update",
			ticket: ticket
			measures: measures
		) success, error-taker
	/*
	Load distributions of own catches
	*/
	catches-mine: (ticket) -> (success, error-taker) !->
		$log.debug "Retrieving my cathces distributions"
		http('POST', "distribution/mine",
			ticket: ticket
		) success, error-taker
	/*
	Load distributions of all catches that includes others
	*/
	catches-others: (ticket) -> (success, error-taker) !->
		$log.debug "Retrieving others cathces distributions"
		http('POST', "distribution/others",
			ticket: ticket
		) success, error-taker
	/*
	Load names of catches with it's count
	*/
	catches-names: (ticket) -> (success, error-taker) !->
		$log.debug "Retrieving names of catches"
		http('POST', "distribution/names",
			ticket: ticket
		) success, error-taker
	/*
	Obtain tide and moon phases
	*/
	conditions: (ticket, timestamp, geoinfo) -> (success, error-taker) !->
		$log.debug "Retrieving conditions: #{timestamp}, #{angular.toJson geoinfo}"
		http('POST', "conditions/get",
			ticket: ticket
			date: timestamp.getTime!
			geoinfo: geoinfo
		) success, error-taker

.factory 'AcceptanceFactory', ($log, LocalStorageFactory) ->
	store =
		taking: []

	successIt = !->
		LocalStorageFactory.acceptance.save true
		if store.taking
			store.taking = null
			for suc in that
				suc!

	isReady: LocalStorageFactory.acceptance.load
	obtain: (success) !->
		if @isReady! then success!
		else store.taking.push success
	success: successIt

.factory 'SocialFactory', ($log, LocalStorageFactory) ->
	facebook-login = (...perm) -> (token-taker, error-taker) !-> ionic.Platform.ready !->
		$log.info "Logging in to Facebook: #{perm}"
		facebookConnectPlugin.login perm
		, (result) !->
			$log.debug "Get access: #{angular.toJson result}"
			token-taker result.authResponse.accessToken
		, error-taker
	facebook-profile = (profile-taker, error-taker) !-> ionic.Platform.ready !->
		$log.info "Getting profile of Facebook"
		facebookConnectPlugin.api "me?fields=name", ['public_profile']
		, (info) !->
			$log.debug "Get profile: #{angular.toJson info}"
			profile-taker do
				id: info.id
				name: info.name
		, error-taker
	facebook-disconnect = (on-success, error-taker) !-> ionic.Platform.ready !->
		$log.info "Disconnecting from facebook"
		facebookConnectPlugin.api "me/permissions?method=delete", []
		, (info) !->
			$log.debug "Revoked: #{angular.toJson info}"
			facebookConnectPlugin.logout (out) !->
				$log.debug "Logout: #{angular.toJson out}"
				on-success!
			, error-taker
		, error-taker

	login: (token-taker, error-taker) !-> ionic.Platform.ready !->
		facebookConnectPlugin.getLoginStatus (res) !->
			account = LocalStorageFactory.account.load!
			$log.debug "Facebook Login Status for #{angular.toJson account}: #{angular.toJson res}"
			if res.status == "connected" && (!account?.id || account.id == res.authResponse.userID)
			then token-taker res.authResponse.accessToken
			else facebook-login('public_profile') token-taker, error-taker
		, (error) !->
			$log.debug "Failed to get Login Status: #{angular.toJson error}"
			facebook-login('public_profile') token-taker, error-taker
	publish: (token-taker, error-taker) !-> ionic.Platform.ready !->
		perm = 'publish_actions'
		facebookConnectPlugin.api "me/permissions", []
		, (res) !->
			$log.debug "Facebook Access Permissions: #{angular.toJson res}"
			pg = res.data |> _.find (.permission == perm)
			if pg?.status == "granted"
			then facebookConnectPlugin.getAccessToken token-taker, error-taker
			else facebook-login(perm) token-taker, error-taker
		, error-taker
	profile: facebook-profile
	disconnect: facebook-disconnect

.factory 'AccountFactory', ($log, $ionicPopup, AcceptanceFactory, LocalStorageFactory, ServerFactory, SocialFactory) ->
	store =
		taking: null
		ticket: null

	stack-login = (ticket-taker, error-taker) !->
		if store.ticket then ticket-taker store.ticket
		else
			taker =
				ticket: ticket-taker
				error: error-taker
			if store.taking
				that.push taker
				$log.debug "Pushed into queue: #{that}"
			else
				broadcast = (proc) !-> if store.taking
					$log.debug "Clear and invoking all listeners: #{store.taking.length}"
					store.taking = null
					that |> _.each proc
				store.taking = [taker]
				$log.debug "First listener in queue: #{taker}"
				AcceptanceFactory.obtain !->
					$log.debug "Get login"
					connect (token) !->
						ServerFactory.login token
						, (ticket) !->
							#store.ticket = ticket
							broadcast (.ticket ticket)
						, (error) !->
							broadcast (.error error.msg)
					, (error) !->
						broadcast (.error error)

	with-ticket = (ticket-proc, success-taker, error-taker) !->
		$log.debug "Getting ticket for: #{ticket-proc}, #{success-taker}"
		auth = !->
			stack-login (ticket) ->
				ticket-proc(ticket) success-taker, (error) !->
					if error.type == ServerFactory.error-types.expired
					then
						store.ticket = null
						auth!
					else error-taker error.msg
			, error-taker
		auth!

	connect = (token-taker, error-taker) !->
		SocialFactory.login (token) !->
			SocialFactory.profile (profile) !->
				LocalStorageFactory.account.save profile
				$log.info "Social connected."
				token-taker token
			, error-taker
		, error-taker

	disconnect = (success-taker, error-taker) !->
		account = LocalStorageFactory.account.load!
		if account?.id
			$log.warn "Social Disconnecting..."
			with-ticket (ticket) ->
				ServerFactory.disconnect ticket
			, (result) !->
				SocialFactory.disconnect !->
					LocalStorageFactory.account.remove!
					$log.info "Social disconnected."
					success-taker!
				, error-taker
			, error-taker
		else
			error-taker "Not connected"

	with-ticket: with-ticket
	connect: (success-taker, error-taker) !->
		connect (token) !->
			with-ticket (ticket) ->
				ServerFactory.connect ticket, token
			, (result) !->
				username = LocalStorageFactory.account.load!?.name
				success-taker username
			, error-taker
		, error-taker
	disconnect: (success-taker, error-taker) !->
		disconnect success-taker, error-taker
	get-username: (success-taker, error-taker) !->
		SocialFactory.profile (profile) !->
			LocalStorageFactory.account.save profile
			success-taker profile.name
		, (error) !->
			$log.error "Failed to get user name: #{error}"
			error-taker "Not Login"

.factory 'SessionFactory', ($log, $http, $ionicPopup, ServerFactory, SocialFactory, ReportFactory, AccountFactory) ->
	store =
		session: null
		upload-info: null

	publish = (report-id) !->
		ReportFactory.publish report-id, !->
			$log.debug "Published session: #{store.session}"
		, (error) !->
			$ionicPopup.alert do
				title: 'Error'
				template: "Failed to post"

	submit = (session, report, success, error-taker) !->
		report.id = ""
		report.user-id = ""
		ServerFactory.submit-report(session, report) (report-id) !->
			report.id = report-id
			ReportFactory.add report
			success report-id
		, (error) !->
			$ionicPopup.alert do
				title: 'Error'
				template: error.msg
			error-taker error

	upload = (photo, success, error) !->
		filename = "user-photo"
		$log.info "Posting photo-image(#{photo}) by $http with #{angular.toJson store.upload-info}"
		data = new FormData()
		for name, value of store.upload-info.params
			data.append name, value
		data.append 'file', photo, filename
		$http.post store.upload-info.url, data,
			transformRequest: angular.identity,
			headers:
				'Content-Type': undefined
		.success (data, status, headers, config) !->
			$log.debug "Success to upload: #{status}: #{data}, #{headers}, #{angular.toJson config}"
			success filename
		.error (data, status, headers, config) !->
			$log.debug "Failed to upload: #{status}: #{data}, #{headers}, #{angular.toJson config}"
			error status

	start: (geoinfo, success, error-taker) !->
		store.session = null
		AccountFactory.with-ticket (ticket) ->
			ServerFactory.start-session ticket, geoinfo
		, (result) !->
			store.session = result.session
			store.upload-info = result.upload
			success!
		, error-taker
	put-photo: (photo, success, inference-taker, error-taker) !->
		if store.session
			upload photo, (filename) !->
				ServerFactory.put-photo(that, filename) (urls) !->
					ServerFactory.infer-photo(that) inference-taker, (error) !->
						store.session = null
						error-taker error.msg
					success urls
				, (error) !->
					store.session = null
					error-taker error.msg
			, (error) !->
				error-taker "Failed to upload"
		else error-taker "No session started"
	finish: (report, is-publish, success, on-finally) !->
		if (session = store.session)
			submit session, report, (report-id) !->
				store.session = null
				$log.info "Session cleared"
				publish(report-id) if is-publish
				success!
				on-finally!
			, on-finally
		else 
			$ionicPopup.alert do
				title: 'Error'
				template: "No session started"
			on-finally!

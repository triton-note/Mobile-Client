.factory 'PostFormFactory', ($window) ->
	/*
		Transform obj for POST body.
	*/
	transform: (obj) -> 
		encode = $window.encodeURIComponent
		joinValue = (value, name) ->
			| value? => switch
				| name? => "#{encode name}=#{encode value}"
				| _     => "#{encode value}"
			| _         => null

		resolve = (obj, parent = null) ->
			eachValue = (f) ->
				for index, value of obj
					resolve value, if parent
						then "#{parent}#{f(index)}"
						else "#{index}"
			switch
			| obj instanceof Array  => eachValue (i) -> "[#i]"
			| obj instanceof Object => eachValue (i) -> ".#i"
			| _                     => [ joinValue(obj, parent) ]
		(_.compact _.flatten resolve obj).join '&'

.factory 'PhotoFactory', ->
	/*
		Select a photo from storage.
		onSuccess(image-uri)
		onFailure(error-message)
	*/
	select: (onSuccess, onFailure = (msg) !-> alert msg) !->
		navigator.camera.getPicture onSuccess, onFailure,
			correctOrientation: true
			encodingType: Camera.EncodingType.JPEG
			sourceType: Camera.PictureSourceType.PHOTOLIBRARY
			destinationType: Camera.DestinationType.FILE_URI

.factory 'ReportFactory', ($log, $ionicPopup, AccountFactory, ServerFactory) ->
	limit = 30
	store =
		reports: []
		hasMore: false

	loadServer = (last-id = null, taker) !->
		AccountFactory.ticket.get (ticket) !->
			ServerFactory.load-reports ticket, limit, last-id, taker
			, (error) !->
				$ionicPopup.alert do
					title: "Failed to load from server"
					template: error.msg
				.then (res) !-> taker null

	cachedList: ->
		store.reports
	hasMore: ->
		store.hasMore
	/*
		Get a report by index of cached list
	*/
	getReport: (index) ->
		$log.debug "Getting report[#{index}]"
		store.reports[index]
	/*
		Clear all cache
	*/
	clear: !->
		store.reports = []
		store.hasMore = true
		$log.debug "Reports cleared."
	/*
		Refresh cache
	*/
	refresh: (success) !->
		loadServer null, (more) !->
			store.reports = more
			store.hasMore = limit <= more.length
			success! if success
	/*
		Load reports from server
	*/
	load: (success) !->
		last-id = store.reports[store.reports.length - 1]?.id ? null
		loadServer last-id, (more) !->
			store.reports = store.reports ++ more
			store.hasMore = limit <= more.length
			$log.info "Loaded #{more.length} reports, Set hasMore = #{store.hasMore}"
			success! if success
	/*
		Add report
	*/
	add: (report) !->
		store.reports = angular.copy([report] ++ store.reports)
	/*
		Remove report specified by index
	*/
	remove: (index, success) !->
		removing-id = store.reports[index].id
		AccountFactory.ticket.get (ticket) !->
			ServerFactory.remove-report ticket, removing-id
			, !->
				$log.info "Deleted report: #{removing-id}"
				store.reports = angular.copy((_.take index, store.reports) ++ (_.drop index + 1, store.reports))
				success!
			, (error) !->
				$ionicPopup.alert do
					title: "Failed to remove from server"
					template: error.msg
	/*
		Update report
	*/
	update: (report, success) ->
		AccountFactory.ticket.get (ticket) !->
			ServerFactory.update-report ticket, report
			, !->
				$log.info "Updated report: #{report.id}"
				success!
			, (error) !->
				$ionicPopup.alert do
					title: "Failed to update to server"
					template: error.msg

.factory 'UnitFactory', (LocalStorageFactory) ->
	inchToCm = 2.54
	pondToKg = 0.4536

	save-current = (units) ->
		LocalStorageFactory.units.save units
	load-current = ->
		if LocalStorageFactory.units.load!
		then that
		else save-current do
			length: 'cm'
			weight: 'kg'
	
	units: -> angular.copy do
		length: ['cm', 'inch']
		weight: ['kg', 'pond']
	load: load-current
	save: save-current
	length: (src) ->
		dst-unit = load-current!.length
		convert = -> switch src.unit
		| dst-unit => src.value
		| 'inch'   => src.value * inchToCm
		| 'cm'     => src.value / inchToCm
		{
			value: convert!
			unit: dstUnit
		}
	weight: (src) ->
		dst-unit = load-current!.weight
		convert = -> switch src.unit
		| dst-unit => src.value
		| 'pond'   => src.value * pondToKg
		| 'kg'     => src.value / pondToKg
		{
			value: convert!
			unit: dstUnit
		}

.factory 'GMapFactory', ($log) ->
	store =
		gmap: null
		marker: null

	create = (center) !->
		store.gmap = plugin.google.maps.Map.getMap do
			mapType: plugin.google.maps.MapTypeId.HYBRID
			controls:
				myLocationButton: true
				zoom: true
		store.gmap.on plugin.google.maps.event.MAP_READY, onReady(center)
	onReady = (center) -> (gmap) !->
		if center
			addMarker center
			gmap.setCenter center
		gmap.showDialog!
	addMarker = (latLng) !->
		store.marker?.remove!
		store.gmap.addMarker {
			position: latLng
		}, (marker) !->
			store.marker = marker

	showMap: (theCenter, setter = null) ->
		center =
			lat: theCenter.latitude
			lng: theCenter.longitude
		if store.gmap
			onReady(center) store.gmap
		else create center

		store.gmap.on plugin.google.maps.event.MAP_CLICK, (latLng) !->
			$log.debug "Map clicked at #{latLng.toUrlValue()} with setter: #{setter}"
			if setter
				setter do
					latitude: latLng.lat
					longitude: latLng.lng
				addMarker latLng
		store.gmap.on plugin.google.maps.event.MAP_CLOSE, (e) !->
			$log.debug "Map close: #{e}"
			store.gmap.clear!
			store.gmap.off!

.factory 'ServerFactory', ($log, $timeout, $http, $ionicPopup, serverURL) ->
	url = (path) -> "#{serverURL}/#{path}"
	retryable = (retry, config, res-taker, error-taker) !->
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
				msg: data
			else
				type: @types.Error
				msg: data
		| 404 =>
			type: @types.fatal
			msg: "Not Found"
		| 501 =>
			type: @types.fatal
			msg: "Not Implemented: #{data}"
		| 503 =>
			type: @types.fatal
			msg: "Service Unavailable: #{data}"
		| _   =>
			type: @types.error
			msg: "Error: #{data}"

	error-types: http-error.types
	/*
	Load the 'terms of use and disclaimer' from server
	*/
	terms-of-use: (taker) !->
		http('GET', "assets/terms-of-use.txt") taker, (error) !->
			$ionicPopup.alert do
				title: 'Server Error'
				template: error.msg
				ok-text: "Exit"
				ok-type: "button-stable"
			.then (res) !-> ionic.Platform.exitApp!
	/*
	Login to Server
	*/
	login: (way, token, ticket-taker, error-taker) !->
		$log.debug "Login to server with #{way} by #{token}"
		http('POST', "login/#{way}",
			token: token
		) ticket-taker, error-taker
	/*
	Get start session by server, then pass to taker
	*/
	start-session: (ticket, geoinfo, session-taker, error-taker) !->
		$log.debug "Starting session by #{ticket} on #{angular.toJson geoinfo}"
		http('POST', "report/new-session/#{ticket}",
			geoinfo: geoinfo
		) session-taker, error-taker
	/*
	Put a photo which is encoded by base64 to session
	*/
	put-photo: (session, photo, inference-taker, error-taker) !->
		$log.debug "Putting a photo with #{session}: #{photo}"
		new FileTransfer().upload photo, url("report/photo/#{session}")
		, (-> it.response) >> angular.fromJson >> inference-taker
		, (-> http-error.gen it.http_status, it.body) >> error-taker
	/*
	Put given report to the session
	*/
	submit-report: (session, report, publishing, success, error-taker) !->
		$log.debug "Submitting report with #{session}: #{angular.toJson report} and #{angular.toJson publishing}"
		http('POST', "report/submit/#{session}",
			report: report
			publishing: publishing
		) success, error-taker
	/*
	Load report from server, then pass to taker
	*/
	load-reports: (ticket, count, last-id, taker, error-taker) !->
		$log.debug "Loading #{count} reports from #{last-id}"
		http('POST', "report/load/#{ticket}",
			count: count
			last: last-id
		) angular.fromJson >> taker, error-taker
	/*
	Remove report from server
	*/
	remove-report: (ticket, id, success, error-taker) !->
		$log.debug "Removing report(#{id})"
		http('POST', "report/remove/#{ticket}",
			id: id
		) success, error-taker
	/*
	Update report to server. ID has to be contain given report.
	*/
	update-report: (ticket, report, success, error-taker) !->
		$log.debug "Updating report: #{angular.toJson report}"
		http('POST', "report/update/#{ticket}",
			report: report
		) success, error-taker

.factory 'LocalStorageFactory', ($log) ->
	names = []
	make = (name, isJson = false) ->
		loader = switch isJson
		| true => (v) -> angular.fromJson v
		| _    => (v) -> v
		saver = switch isJson
		| true => (v) -> angular.toJson v
		| _    => (v) -> v

		names.push name

		load: -> 
			v = window.localStorage[name] ? null
			$log.debug "localStorage['#{name}'] => #{v}"
			if v then loader(v)	else null
		save: (v) ->
			value = if v then saver(v) else null
			$log.debug "localStorage['#{name}'] <= #{value}"
			window.localStorage[name] = value
			v
		remove: !->
			window.localStorage.removeItem name

	clear-all: !-> for name in names
		window.localStorage.removeItem name
	/*
	List of String value to express the way of login
	*/
	login-way: make 'login-way'
	/*
	Boolean value for acceptance of 'Terms Of Use and Disclaimer'
	*/
	acceptance: make 'Acceptance'
	/*
	Unit setting
	*/
	units: make 'Units', true

.factory 'SocialFactory', ($log) ->
	facebook = (...perm) -> (token-taker, error-taker) !->
		$log.info "Logging in to Facebook: #{perm}"
		facebookConnectPlugin.login perm
			, (data) !-> token-taker data.authResponse.accessToken
			, error-taker
	google = (...perm) -> (token-taker, error-taker) !->
		# TODO

	ways:
		facebook: 'facebook'
		google: 'google'
	facebook:
		login: facebook 'basic_info'
		publish: facebook 'publish_actions'
	google:
		login: google 'email'
		publish: google 'publish'

.factory 'SessionFactory', ($log, $ionicPopup, ServerFactory, SocialFactory, ReportFactory, AccountFactory) ->
	store =
		session: null

	permit-publish = (way, token-taker, error-taker) !->
		| SocialFactory.ways.facebook => SocialFactory.facebook.publish token-taker, error-taker
		| _             => ionic.Platform.exitApp!

	submit = (session, success, report) -> (publishing = null) !->
		ServerFactory.submit-report session, report, publishing
		, !->
			ReportFactory.add report
			success!
		, (error) !->
			$ionicPopup.alert do
				title: 'Error'
				template: error.msg

	start: (geoinfo, success, error-taker) !->
		get-session = !->
			store.session = null
			AccountFactory.ticket.get (ticket) !->
				ServerFactory.start-session ticket, geoinfo
				, (session) !->
					store.session = session
					success!
				, (error) !->
					switch error.type
					| ServerFactory.error-types.expired =>
						# When ticket is time out
						start-session!
					| _ => error-taker error.msg
		get-session!
	put-photo: (uri, inference-taker, error-taker) !->
		if store.session
		then ServerFactory.put-photo that, uri, inference-taker, (-> it.msg) >> error-taker
		else error-taker "No session started"
	finish: (report, publish-way, success) !->
		if store.session
			sub = submit that, success, report
			store.session = null
			if publish-way?.length > 0 then
				permit-publish publish-way
				, (token) !->
					sub do
						way: publish-way
						token: token
				, (error) !->
					$ionicPopup.alert do
						title: 'Rejected'
						template: error
			else sub!

.factory 'AccountFactory', ($log, $ionicPopup, AcceptanceFactory, LocalStorageFactory, ServerFactory, SocialFactory) ->
	store =
		ticket: null

	getLoginWay = (way-taker) !->
		if LocalStorageFactory.login-way.load! then way-taker that
		else AcceptanceFactory.obtain !->
			$ionicPopup.show do
				template: 'Select for Login'
				buttons:
					{
						text: ''
						type: 'button icon ion-social-facebook button-positive'
						onTap: (e) -> SocialFactory.ways.facebook
					},{
						text: ''
						type: 'button icon ion-social-googleplus button-assertive'
						onTap: (e) -> SocialFactory.ways.google
					}
			.then way-taker

	doLogin = (token-taker, error-taker) !->
		getLoginWay (way) !-> switch way
		| SocialFactory.ways.facebook => SocialFactory.facebook.login token-taker(way), error-taker
		| _                           => ionic.Platform.exitApp!

	login = (ticket-taker) !->
		error-taker = (error-msg) !->
			$ionicPopup.alert do
				title: 'Error'
				template: error-msg
			.then (res) !-> action!
		token-taker = (way-name) -> (token) !->
			LocalStorageFactory.login-way.save way-name
			ServerFactory.login way-name, token, ticket-taker, (error) !->
				if error.type != ServerFactory.error-types.fatal
					error-taker error.msg
		action = !-> doLogin token-taker, error-taker
		action!

	ticket:
		get: (ticket-taker = (t) !-> $log.debug "Ticket: #{t}") !->
			if store.ticket then ticket-taker that
			else
				login (ticket) !->
					store.ticket = ticket
					ticket-taker ticket

.factory 'AcceptanceFactory', ($log, $rootScope, $ionicModal, $ionicPopup, LocalStorageFactory, ServerFactory) ->
	scope = $rootScope.$new(true)
	scope.accept = !->
		$log.info "Acceptance obtained"
		LocalStorageFactory.acceptance.save true
		scope.modal.remove!
		scope.success!
	scope.reject = !->
		$ionicPopup.alert do
			title: "Good Bye !"
			ok-text: "Exit"
			ok-type: "button-stable"
		.then (res) !->
			ionic.Platform.exitApp!

	obtain: (success) !->
		if LocalStorageFactory.acceptance.load!
		then success!
		else ServerFactory.terms-of-use (text) !->
			scope.terms-of-use = text
			$ionicModal.fromTemplateUrl 'template/terms-of-use.html'
			, (modal) !->
				scope.success = success
				scope.modal = modal
				modal.show!
			,
				scope: scope
				animation: 'slide-in-up'

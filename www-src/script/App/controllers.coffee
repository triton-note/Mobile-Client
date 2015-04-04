angular.module('triton_note.controllers', [])
.controller 'AcceptanceCtrl', ($log, $scope, $state, $stateParams, $ionicHistory, $ionicLoading, $ionicPopup, AcceptanceFactory) ->
	$ionicLoading.show()
	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter AcceptanceCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$scope.accept = ->
			$log.info "Acceptance obtained"
			AcceptanceFactory.success()
			$ionicHistory.nextViewOptions
				disableAnimate: true
				disableBack: true
			$state.go 'home'

.controller 'SNSCtrl', ($log, $scope, $stateParams, $ionicHistory, $ionicLoading, $ionicPopup, AccountFactory, ReportFactory) ->
	$ionicLoading.show()
	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter SNSCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		AccountFactory.getUsername (username) ->
			$scope.$apply -> $scope.done username
		, (errorMsg) ->
			$scope.$apply -> $scope.done()

	$scope.checkSocial = ->
		$ionicLoading.show()
		next = $scope.social.username is null
		$log.debug "Changing social: #{next}"
		onError = (error) ->
			$log.error "Erorr on Facebook: #{angular.toJson error}"
			$scope.done $scope.social.username
			$ionicPopup.alert
				title: "Rejected"
		if next
			AccountFactory.connect $scope.done, onError
		else
			AccountFactory.disconnect ->
				ReportFactory.clearList()
				$ionicHistory.clearCache()
				$log.warn "SNSCtrl: Cache Cleared()"
				$scope.done()
				$ionicPopup.alert
					title: "No social connection"
					template: "Please login to Facebook, if you want to continue this app."
			, onError
	$scope.done = (username = null) ->
		$scope.social =
			username: username
			login: username isnt null
		$ionicLoading.hide()
		$log.debug "Account connection: #{angular.toJson $scope.social}"

.controller 'PreferencesCtrl', ($log, $scope, $stateParams, $ionicSideMenuDelegate, $ionicLoading, $ionicPopup, UnitFactory) ->
	$ionicLoading.show()
	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter PreferencesCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$ionicLoading.show()
		UnitFactory.load (units) ->
			$scope.unit = units
			$ionicLoading.hide()

	$scope.submit = ->
		UnitFactory.save $scope.unit
		$ionicSideMenuDelegate.toggleLeft true
	$scope.units = UnitFactory.units()

.controller 'ListReportsCtrl', ($log, $scope, ReportFactory) ->
	$scope.reports = ReportFactory.cachedList
	$scope.hasMoreReports = ReportFactory.hasMore
	$scope.refresh = ->
		$log.debug "Refresh Reports List ..."
		ReportFactory.refresh ->
			$scope.$broadcast 'scroll.refreshComplete'
	$scope.moreReports = -> if ReportFactory.hasMore()
		$log.debug "Get More Reports List ..."
		ReportFactory.load ->
			$scope.$broadcast 'scroll.infiniteScrollComplete'

.controller 'ShowReportCtrl', ($log, $timeout, $state, $stateParams, $ionicHistory, $scope, $ionicPopover, $ionicPopup, ReportFactory, ConditionFactory) ->
	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter ShowReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$scope.popover = {}
		['show_location', 'option_buttons'].forEach (name) ->
			$ionicPopover.fromTemplateUrl name,
				scope: $scope
			.then (popover) ->
				$scope.popover[name] = popover
		$scope.popoverHide = ->
			for _, p of $scope.popover
				p.hide()

		$scope.shouldClear = true
		if $stateParams.index and ReportFactory.current().index is null
			$scope.report = ReportFactory.getReport($scope.index = Number($stateParams.index))
		else
			c = ReportFactory.current()
			$scope.index = c.index
			$scope.report = c.report
		$scope.tideIcon = ConditionFactory.tidePhases.filter((v) -> v.name is $scope.report.condition?.tide).map((v) -> v.icon)[0]
		$scope.moonIcon = ConditionFactory.moonPhases[$scope.report.condition?.moon]
		
		$scope.showLocationGmap =
			center: new google.maps.LatLng($scope.report.location.geoinfo.latitude, $scope.report.location.geoinfo.longitude)
			map: null
			marker: null
		
		$log.debug "Show Report: #{angular.toJson $scope.report}"

	$scope.$on '$ionicView.beforeLeave', (event, state) ->
		$log.debug "Before Leave ShowReportCtrl: event=#{angular.toJson event}"
		ReportFactory.clearCurrent() if $scope.shouldClear
		for _, p of $scope.popover
			p?.remove()
		$scope.showLocationGmap.map = null
		$scope.showLocationGmap.marker = null

	$scope.previewMap = ($event) ->
		gmap = $scope.showLocationGmap
		$scope.popover.show_location.show $event
		.then ->
			div = document.getElementById "show-gmap"
			unless gmap.map
				gmap.map = new google.maps.Map div,
					mapTypeId: google.maps.MapTypeId.HYBRID
					disableDefaultUI: true
			gmap.map.setCenter gmap.center
			gmap.map.setZoom 8

			gmap.marker?.setMap null
			gmap.marker = new google.maps.Marker
				title: $scope.report.location.name
				map: gmap.map
				position: gmap.center
				animation: google.maps.Animation.DROP

			google.maps.event.addDomListener div, 'click', ->
				$scope.useCurrent()
				$state.go "view-on-map"

	$scope.useCurrent = ->
		$scope.shouldClear = false
	$scope.delete = ->
		$scope.popoverHide()
		$ionicPopup.confirm
			title: "Delete Report"
			template: "Are you sure to delete this report ?"
		.then (res) -> if res
			ReportFactory.remove $scope.index, ->
				$log.debug "Remove completed."
			$ionicHistory.goBack()
	$scope.publish = ->
		$scope.popoverHide()
		$ionicPopup.confirm
			title: "Publish Report"
			template: "Are you sure to post this report to Facebook ?"
		.then (res) -> if res
			ReportFactory.publish $scope.report.id, ->
				$log.debug "Publish completed."
				$ionicPopup.alert
					title: 'Completed to post'
			, (error) ->
				$ionicPopup.alert
					title: 'Error'
					template: "Failed to post"

.controller 'EditReportCtrl', ($log, $stateParams, $scope, $ionicHistory, $ionicLoading, ReportFactory) ->
	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter EditReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$scope.shouldClear = true
		$scope.report = ReportFactory.current().report

	$scope.$on '$ionicView.beforeLeave', (event, state) ->
		$log.debug "Before Leave EditReportCtrl: event=#{angular.toJson event}"
		ReportFactory.clearCurrent() if $scope.shouldClear

	$scope.useCurrent = ->
		$scope.shouldClear = false
	$scope.submit = ->
		$ionicLoading.show()
		ReportFactory.updateByCurrent ->
			$log.debug "Edit completed."
			$ionicHistory.goBack()
		, $ionicLoading.hide
	$scope.submissionEnabled = ->
		!!$scope.report?.location?.name

.controller 'AddReportCtrl', ($log, $timeout, $ionicPlatform, $scope, $stateParams, $ionicHistory, $ionicLoading, $ionicPopover, $ionicPopup, PhotoFactory, SessionFactory, ReportFactory, GMapFactory, ConditionFactory) ->
	$log.debug "Init AddReportCtrl"
	$ionicLoading.show()
	$scope.$on '$ionicView.loaded', (event, state) ->
		$log.debug "Loaded AddReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"

		$ionicPopover.fromTemplateUrl 'confirm_submit',
			scope: $scope
		.then (popover) ->
			$scope.confirm_submit = popover

	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter AddReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$scope.shouldClear = true

		if (cur = ReportFactory.current().report)
			$ionicLoading.hide()
			$scope.report = cur
			$log.debug "Getting current report: #{angular.toJson $scope.report}"
			$scope.submission.enabled = !!$scope.report.photo.original
		else
			onError = (title) -> (errorMsg) ->
				$ionicLoading.hide()
				$ionicPopup.alert
					title: title
					template: errorMsg
				.then $ionicHistory.goBack
			store =
				photo: null
			PhotoFactory.select (photo) ->
				uri = URL.createObjectURL photo
				console.log "Selected photo info: #{uri}"
				$scope.report = ReportFactory.newCurrent uri
				$ionicLoading.hide()
				store.photo = photo
			, (info) ->
				console.log "Exif info: #{angular.toJson info}"
				upload = (geoinfo) ->
					$scope.report.dateAt = new Date(Math.round((info?.timestamp ? new Date()).getTime() / 1000) * 1000)
					$scope.report.location.geoinfo = geoinfo
					$log.debug "Created report: #{angular.toJson $scope.report}"
					SessionFactory.start geoinfo, ->
						SessionFactory.putPhoto store.photo
						, (result) ->
							$log.debug "Get result of upload: #{angular.toJson result}"
							$scope.submission.enabled = true
							$timeout ->
								$log.debug "Updating photo url: #{angular.toJson result.url}"
								angular.copy result.url, $scope.report.photo
							, 100
						, (inference) ->
							$log.debug "Get inference: #{angular.toJson inference}"
							if (loc = inference.location)
								$scope.report.location.name = loc
							if inference.fishes?.length > 0
								$scope.report.fishes = inference.fishes
						, onError "Failed to upload"
					, onError "Error"
				if info?.geoinfo
					upload info.geoinfo
				else
					$log.warn "Getting current location..."
					GMapFactory.getGeoinfo upload, (error) ->
						$log.error "Geolocation Error: #{angular.toJson error}"
						upload
							latitude: 0
							longitude: 0
			, onError "Need one photo"

	$scope.$on '$ionicView.beforeLeave', (event, state) ->
		$log.debug "Before Leave AddReportCtrl: event=#{angular.toJson event}"
		ReportFactory.clearCurrent() if $scope.shouldClear

	$scope.useCurrent = ->
		$scope.shouldClear = false
	$scope.submit = ->
		$ionicLoading.show()
		if !$scope.report.location.name
			$scope.report.location.name = "MySpot"
		SessionFactory.finish $scope.report, $scope.submission.publishing, ->
			$ionicHistory.goBack()
		, $ionicLoading.hide
	$scope.submission =
		enabled: false
		publishing: false

.controller 'ReportOnMapCtrl', ($log, $scope, $stateParams, $ionicHistory, $ionicPopover, GMapFactory, ReportFactory) ->
	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter ReportOnMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$scope.report = ReportFactory.current().report
		GMapFactory.onDiv $scope, 'edit-map', (gmap) ->
			$scope.$on 'popover.hidden', ->
				gmap.setClickable true
			$scope.showViewOptions = (event) ->
				gmap.setClickable false
				$scope.popoverView.show event
			if $stateParams.edit
				$scope.geoinfo = $scope.report.location.geoinfo
				GMapFactory.onTap (geoinfo) ->
					$scope.geoinfo = geoinfo
					GMapFactory.putMarker geoinfo
		, $scope.report.location.geoinfo
		$scope.view =
			gmap:
				type: GMapFactory.getMapType()
				types: GMapFactory.getMapTypes()
		$scope.$watch 'view.gmap.type', (value) ->
			$log.debug "Changing 'view.gmap.type': #{angular.toJson value}"
			GMapFactory.setMapType value
		$ionicPopover.fromTemplateUrl 'view_map_view',
			scope: $scope
		.then (pop) ->
			$scope.popoverView = pop

	$scope.submit = ->
		if (geoinfo = $scope.geoinfo)
			$scope.report.location.geoinfo = geoinfo
		$ionicHistory.goBack()

.controller 'DistributionMapCtrl', ($log, $ionicPlatform, $scope, $state, $stateParams, $ionicSideMenuDelegate, $ionicPopover, $ionicLoading, GMapFactory, DistributionFactory, ReportFactory) ->
	$ionicLoading.show()
	$scope.$on '$ionicView.loaded', (event, state) ->
		$log.debug "Loaded DistributionMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$scope.view =
			others: false
			name: null
			gmap:
				type: GMapFactory.getMapType()
				types: GMapFactory.getMapTypes()
		$scope.$watch 'view.others', (value) ->
			$log.debug "Changing 'view.person': #{angular.toJson value}"
			$scope.mapDistribution()
		$scope.$watch 'view.name', (value) ->
			$log.debug "Changing 'view.fish': #{angular.toJson value}"
			$scope.mapDistribution()
		$scope.$watch 'view.gmap.type', (value) ->
			$log.debug "Changing 'view.gmap.type': #{angular.toJson value}"
			GMapFactory.setMapType value
		$ionicPopover.fromTemplateUrl 'distribution_map_options',
			scope: $scope
		.then (pop) ->
			$scope.popoverOptions = pop
		$scope.showOptions = (event) ->
			$scope.gmap.setClickable false
			$scope.popoverOptions.show event
		$ionicPopover.fromTemplateUrl 'distribution_map_view',
			scope: $scope
		.then (pop) ->
			$scope.popoverView = pop
		$scope.showViewOptions = (event) ->
			$scope.gmap.setClickable false
			$scope.popoverView.show event
		$scope.$on 'popover.hidden', ->
			$scope.gmap.setClickable true

		icons = [1..9].map (count) ->
			size = 32
			center = size / 2
			r = ->
				min = 4
				max = center - 1
				v = min + (max - min) * count / 10
				Math.min max, v
			canvas = document.createElement 'canvas'
			canvas.width = size
			canvas.height = size
			context = canvas.getContext '2d'
			context.beginPath()
			context.strokeStyle = "rgb(80, 0, 0)"
			context.fillStyle = "rgba(255, 40, 0, 0.7)"
			context.arc center, center, r(), 0, Math.pi * 2, true
			context.stroke()
			context.fill()
			canvas.toDataURL()
		$scope.mapDistribution = -> if gmap = $scope.gmap
			others = $scope.view.others
			fishName = $scope.view.name
			mapMine = (list) ->
				$log.debug "Mapping my distribution (filtered by '#{fishName}'): #{list}"
				gmap.clear()
				detail = (fish) -> (marker) ->
					marker.on plugin.google.maps.event.INFO_CLICK, ->
						$log.debug "Detail for fish: #{angular.toJson fish}"
						findOr = (fail) ->
							index = ReportFactory.getIndex fish.reportId
							if index >= 0
								GMapFactory.clear()
								$state.go 'show-report',
									index: index
							else fail()
						findOr ->
							ReportFactory.refresh ->
								findOr ->
									$log.error "Report not found by id: #{fish.reportId}"
				for fish in list
					gmap.addMarker
						title: "#{fish.name} x #{fish.count}"
						snippet: fish.date.toLocaleDateString()
						position:
							lat: fish.geoinfo.latitude
							lng: fish.geoinfo.longitude
						, detail fish
			mapOthers = (list) ->
				$log.debug "Mapping other's distribution (filtered by '#{fishName}'): #{list}"
				gmap.clear()
				for fish in list
					gmap.addMarker
						title: "#{fish.name} x #{fish.count}"
						icon: icons[(Math.min fish.count, 10) - 1]
						position:
							lat: fish.geoinfo.latitude
							lng: fish.geoinfo.longitude
			if others
				DistributionFactory.others fishName, mapOthers
			else
				DistributionFactory.mine fishName, mapMine

	$scope.$on '$ionicView.enter', (event, state) ->
		$log.debug "Enter DistributionMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}"
		$ionicLoading.show()
		GMapFactory.onDiv $scope, 'distribution-map', (gmap) ->
			$scope.gmap = gmap
			$scope.mapDistribution()
			$ionicLoading.hide()
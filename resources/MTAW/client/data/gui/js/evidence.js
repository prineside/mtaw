Evidence = {
	meetings : {},						// meetID => meetData	
	
	filters : {
		minDate : null,
		maxDate : null,
		minX : null,
		maxX : null,
		minY : null,
		maxY : null,
		avatar : null
	},
	
	showMeetingList : function() {
		$( '#evidence-meetings' ).addClass( 'visible' );
	},
	
	hideMeetingList : function() {
		$( '#evidence-meetings' ).removeClass( 'visible' );
	},
	
	setMeetings : function( meetings ) {
		Evidence.meetings = meetings;
		
		// console.log( meetings );
		var list = $( '#evidence-meetings-list' );
		list.html( '' );
		
		$.each( meetings, function( meetingID, meetingData ) {
			var eventTypeCountElements = []
			$.each( meetingData.eventTypeCount, function( eventType, eventCount ) {
				eventTypeCountElements.push(
					$( '<div class="event-type event-type-' + eventType + '" />' ).text( eventCount )
				);
			} );
			
			list.append(
				$( '<div class="meeting" />' ).append(
					$( '<div class="meeting-avatar" />' ).append(
						$( '<img />' ).attr( 'src', meetingData.avatarFilePath )
					),
					$( '<div class="meeting-event-count" />' ).text( meetingData.eventCount ),
					$( '<div class="meeting-events-by-types" />' ).append( eventTypeCountElements ),
					$( '<div class="meeting-time" />' ).append(
						$( '<div class="meeting-time-ago" />' ).html( 'N минут назад' ),
						$( '<div class="meeting-time-date" />' ).html( meetingData.lastTime )
					),
					$( '<div class="meeting-location" />' ).html( "Неизвестно" ),
					$( '<div class="meeting-remembered" />' ).html( meetingData.remembered ? 1 : 0 )
				)
			);
		} );
		
		Evidence.updateMeetingList();
	},
	
	// Убирает фильтры списка встреч
	removeMeetingListFilters : function() {
		Evidence.filters = {
			minDate : null,
			maxDate : null,
			minX : null,
			maxX : null,
			minY : null,
			maxY : null,
			avatar : null
		};
		
		Evidence.updateMeetingList();
	},
	
	// Обновляет список встреч, применяя фильтры
	updateMeetingList : function() {
		//$( '#evidence-meetings-list' ).html( '' );
		//Evidence.meetings
	}
};
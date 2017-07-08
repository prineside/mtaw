"use strict";
var Popup = {
	messageIcons : {
		info : 'info-circle',
		warning : 'exclamation-circle',
		error : 'exclamation-triangle',
		success : 'check-circle'
	},
	
	init : function() {
		
	},
	
	// Показать сообщение
	show : function( message, type, icon, delay ) {
		if ( typeof( type ) == 'undefined' ) {
			type = 'info';
		}
		if ( typeof( icon ) == 'undefined' ) {
			icon = Popup.messageIcons[ type ];
		}
		if ( typeof( delay ) == 'undefined' ) {
			delay = 5000;
		}
		
		var messageElement = $( '<div class="popup-message ' + type + '" />' );
		$( messageElement ).append( 
			$( '<table />' ).append(
				$( '<tr />' ).append(
					$( '<td class="message-icon" />' ).append( 
						$( '<i class="fa fa-' + icon + '" />' )
					),
					$( '<td class="message-content" />' ).html( message )
				)
			)
		);
		
		$( '#popup' ).append( messageElement );
		setTimeout( function() { Popup.hide( messageElement ); }, delay );
		setTimeout( function() { $( messageElement ).addClass( 'visible'); }, 20 );
		
		$( messageElement ).on( 'click', function() { Popup.hide( messageElement ); } );
		
		return messageElement;
	},
	
	hide : function( messageElement ) {
		$( messageElement ).removeClass( 'visible' );
		setTimeout( function() { $( messageElement ).remove(); }, 300 );
	}
};
$( document ).ready( function() {
	Popup.init();
} );
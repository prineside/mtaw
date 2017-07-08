"use strict";
var LoginForm = {
	inRegistrationMode : false,
	soundEnabled : true,
	
	init : function() {
		// Бинд нажатия Enter в форме входа (отправка формы)
		$( '#login-form' ).bind( 'keydown', function( e ) {
			if ( $( '#login-form' ).is( '.visible' ) ) {
				if ( e.which == 13 ) {	// Enter
					// Отправка формы
					LoginForm.sendForm();
				}
			}
		} );
	}, 
	
	setVisible : function( setVisible ) {
		if ( typeof( setVisible ) == 'undefined' ) {
			setVisible = true;
		}
		
		// TODO inRegistrationMode
		if ( setVisible ) {
			$( '#login-form' ).addClass( 'visible' );
			
			// Установка последнего логина
			if ( localStorage.getItem( "LoginForm.lastLogin" ) ) {
				$( '#login-form-input-login' ).val( localStorage.getItem( "LoginForm.lastLogin" ) );
				$( '#login-form-input-password' ).focus();
			} else {
				$( '#login-form-input-login' ).focus();
			}
			
			var posX = $( window ).outerWidth() / 2 - $( '#login-form' ).outerWidth() / 2;
			var posY = $(window).outerHeight() / 2 - $( '#login-form' ).outerHeight() / 2;
			var width = $( '#login-form' ).outerWidth();
			var height = $( '#login-form' ).outerHeight();
			
			Main.runLua( "GUIBlur.add(\"LoginForm\", " + posX + "," + posY + "," + width + "," + height + ")" );
		} else {
			$( '#login-form' ).removeClass( 'visible' );
			Main.runLua( "GUIBlur.remove( \"LoginForm\" )" );
		}
	},
	
	setSoundEnabled : function( isEnabled ) {
		if ( isEnabled ) {
			$( '#login-form-sound-toggle' ).html( '<i class="fa fa-volume-up"></i>' );
		} else {
			$( '#login-form-sound-toggle' ).html( '<i class="fa fa-volume-off"></i>' );
		}
		Main.sendEvent( "LoginForm.setSoundEnabled", isEnabled );
		LoginForm.soundEnabled = isEnabled;
	},
	
	// Режим регистрации
	registrationMode : function( isEnabled ) {
		Popup.show( "Для регистрации перейдите на сайт <b>prineside.com</b>", "info" );
	},
	
	sendForm : function() {
		var login = $( '#login-form-input-login' ).val();
		var password = $( '#login-form-input-password' ).val();
		
		localStorage.setItem( "LoginForm.lastLogin", login );
		Main.sendEvent( "LoginForm.formSubmit", login, password );
	}
};
$( document ).ready( function() {
	LoginForm.init();
} );
// Основной графический интерфейс (здоровье, уровни и т.д.)
"use strict";
var GUI = {
	cursorPosition : { x : 0, y : 0 },
	screenSize : { x : 0, y : 0 },
	
	init : function() {
		$( document ).bind( 'mousemove', function( e ) {
			GUI.cursorPosition.x = e.clientX;
			GUI.cursorPosition.y = e.clientY;
		} );
		
		GUI.screenSize.x = screen.width;
		GUI.screenSize.y = screen.height;
	},
	
	setVisible : function( setVisible ) {
		if ( typeof( setVisible ) == 'undefined' ) {
			setVisible = true;
		}
		
		if ( setVisible ) {
			$( '#gui' ).addClass( 'visible' );
		} else {
			$( '#gui' ).removeClass( 'visible' );
		}
	},
	
	showDialog : function( message, icon, buttons ) {
		if ( icon == null || icon == false ) {
			$( '#gui-dialog-content-icon' ).hide();
			$( '#gui-dialog-content-message' ).removeClass( 'aside-icon' );
		} else {
			$( '#gui-dialog-content-icon' ).html( '<i class="fa fa-' + icon + '"></i>' ).show();
			$( '#gui-dialog-content-message' ).addClass( 'aside-icon' );
		}
		
		$( '#gui-dialog-content-message' ).html( message );
		
		$( '#gui-dialog-buttons' ).html( '' ).append( buttons );
		
		$( '#gui-dialog' ).show();
		
		$( '#gui-dialog' ).css( 'margin-top', ( -$( '#gui-dialog' ).height() / 2 ) + "px" );
	},
	
	hideDialog : function() {
		$( '#gui-dialog' ).hide();
	},
	
	setHealth : function( value ) {
		var percents = value;
		if ( percents > 100 ) { 
			percents = 100; 
		} else if ( percents < 0 ) {
			percents = 0;
		}
		$( '#gui-health .gui-bar-line' ).css( 'width', percents + "%" );
		$( '#gui-health .gui-bar-value' ).text( Math.round( value ) );
	},
	
	setSatiety : function( value ) {
		var percents = value;
		if ( percents > 100 ) { 
			percents = 100; 
		} else if ( percents < 0 ) {
			percents = 0;
		}
		$( '#gui-satiety .gui-bar-line' ).css( 'width', percents + "%" );
		$( '#gui-satiety .gui-bar-value' ).text( Math.round( value ) );
	},
	
	setMoney : function( value ) {
		$( '#gui-money' ).text( '$' + value );
	}
};
$( document ).ready( GUI.init );
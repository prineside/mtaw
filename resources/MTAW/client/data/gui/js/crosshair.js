"use strict";
var Crosshair = {
	element : null,
	visible : true,
	
	init : function() {
		Crosshair.element = $( '#crosshair' );
	},
	
	// Показать курсор (вызывается при старте клиенте, чтобы во время загрузки не было видно его)
	enable : function() {
		$( '#crosshair' ).addClass( 'enabled' );
	},
	
	setVisible : function( visible ) {
		if ( visible ) {
			Crosshair.element.removeClass( 'hidden' );
			Crosshair.visible = true;
		} else {
			Crosshair.element.addClass( 'hidden' );
			Crosshair.visible = false;
		}
	},
	
	// Показать подсказку возле курсора. Если showActionKey установлен в true, будет показана кнопка взаимодействия
	setLabel : function( labelText, labelDescription, labelColor, showActionKey, actionKey ) {
		if ( showActionKey == true ) {
			$( '#crosshair-label' ).addClass( 'action-key-visible' );
		} else {
			$( '#crosshair-label' ).removeClass( 'action-key-visible' );
		}
		
		//console.log( labelText, labelDescription, labelColor, showActionKey, actionKey );
		
		if ( actionKey == false || actionKey == undefined || actionKey == null ) {
			$( '#crosshair-label-action-key' ).text( 'E' );
		} else {
			if ( actionKey == "RMB" ) {
				// Правая кнопка мыши
				$( '#crosshair-label-action-key' ).html( "<div class='action-key-rmb' />" );
			} else if ( actionKey == "LMB" ) {
				// Левая кнопка мыши
				$( '#crosshair-label-action-key' ).html( "<div class='action-key-lmb' />" );
			} else {
				$( '#crosshair-label-action-key' ).text( actionKey );
			}
		}
		
		$( '#crosshair-label-text-main' ).html( labelText );
		$( '#crosshair-label-text-progress-overlay' ).html( labelText );
		$( '#crosshair-label-description' ).html( labelDescription );
		
		if ( labelColor != null && labelColor != undefined && labelColor != false ) {
			$( '#crosshair-label-text' ).css( 'color', labelColor );
		} else {
			$( '#crosshair-label-text' ).css( 'color', 'inherit' );
		}
		$( '#crosshair-label' ).show();
	},
	
	// Убрать подсказку возле курсора
	removeLabel : function() {
		$( '#crosshair-label' ).hide();
	},
	
	// Установить прогресс действия (цвет текста слева направо изменится)
	setLabelProgress : function( progress, color ) {
		//console.log( $( '#crosshair-label-text-main' ).width() );
		
		if ( color != false && color != undefined && color != null ) {
			$( '#crosshair-label-text-progress-overlay' ).css( 'color', color );
		} else {
			$( '#crosshair-label-text-progress-overlay' ).css( 'color', '#4CAF50' );
		}
		
		$( '#crosshair-label-text-progress-overlay' ).css( 'width', ( $( '#crosshair-label-text-main' ).width() * progress / 100 ) + 'px' );
		$( '#crosshair-label-text-progress-overlay' ).show();
	},
	
	removeLabelProgress : function() {
		$( '#crosshair-label-text-progress-overlay' ).hide();
	}
};
$( document ).ready( function() {
	Crosshair.init();
} );
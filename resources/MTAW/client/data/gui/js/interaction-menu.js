// Меню взаимодействия с окружением (например, с игроком или с транспортом)
"use strict";
var InteractionMenu = {
	
	// Показать меню взаимодействия
	show : function( title, description, menuItems, iconContent ) {
		console.log( "Показываем меню", title, description, menuItems );
		$( '#interaction-menu-title' ).html( title );
		$( '#interaction-menu-description' ).html( description );
		if ( iconContent == undefined || iconContent == null || iconContent == false ) {
			// Значок не установлен - убираем
			$( '#interaction-menu-icon' ).hide();
		} else {
			// Значок установлен - вставляем как html
			$( '#interaction-menu-icon' ).html( iconContent ).show();
		}
		
		// Установка элементов
		$( '#interaction-menu-content' ).html( '' );
		$.each( menuItems, function( k, item ) {
			var itemElement = $( '<div class="interaction-menu-item" />' )
				.append( 
					$( '<i class="fa fa-' + item.icon + '" />' ),
					$( '<span />' ).html( item.title )
				);
			
			$( itemElement ).on( 'click', function( e ) {
				console.log( item.handler );
				Main.sendEvent( "InteractionMenu.click", item.handler );
			} );
			
			$( '#interaction-menu-content' ).append( itemElement );
		} );
		
		$( '#interaction-menu' ).addClass( 'visible' );
	},
	
	// Спрятать меню взаимодействия
	hide : function() {
		console.log( "Скрываем меню" );
		$( '#interaction-menu' ).removeClass( 'visible' );
	}
};

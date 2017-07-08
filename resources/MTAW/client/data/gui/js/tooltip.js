"use strict";
var Tooltip = {
	lastTarget : null,
	
	init : function() {
		// Обрабатываем движение мышки
		$( window ).bind( "mousemove", function( e ) {
			if ( Tooltip.lastTarget != e.target ) {
				var tipText = Tooltip.getParentTitleAttr( e.target );
				if ( tipText.length == undefined || tipText.length == 0 ) {
					tipText = null;
				}
				Tooltip.updateTooltip( tipText );
				Tooltip.lastTarget = e.target;
			}
		} );
	},
	
	// Получить атрибут title элемента или его родителей. Если не найдено, возвращает null
	getParentTitleAttr : function( element ) {
		if ( $( element ).prop( 'tagName' ) == 'body' ) {
			return null;
		} else {
			var titleAttr = $( element ).attr( 'title' );
			if ( titleAttr == undefined ) {
				//console.log( "undefined:", titleAttr );
				return Tooltip.getParentTitleAttr( $( element ).parent() );
			} else {
				//console.log( "defined:", titleAttr );
				return titleAttr;
			}
		}
	},
	
	updateTooltipPosition : function( e ) {
		$( Main.tooltipElement ).css( {
			top : e.clientY,
			left : e.clientX
		} );
	},
	
	// Внутренняя функция для обновления подсказки под мышкой
	updateTooltip : function( tooltip ) {
		if ( tooltip == null ) {
			// Спрятать подсказку
			$( Main.tooltipElement ).hide();
			$( 'body' ).off( 'mousemove', Tooltip.updateTooltipPosition );
		} else {
			// Показать подсказку
			$( Main.tooltipElement ).html( tooltip ).show();
			$( 'body' ).on( 'mousemove', Tooltip.updateTooltipPosition );
		}
	},
};

$( document ).ready( function() {
	Tooltip.init();
} );
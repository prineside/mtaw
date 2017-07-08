"use strict";
var Objective = {
	
	// Установить шаблон списка целей
	setObjectiveTypes : function( objectiveTypes ) {
		$( '#inv-menu-objective-items' ).html( '' );
		$.each( objectiveTypes, function( objectiveAlias, objectiveInfo ) {
			var itemElement = $( '<div class="inv-menu-objective-item" />' )
				.attr( 'title', objectiveInfo.description + '<br>Опыт за выполнение: ' + objectiveInfo.experience + 'xp' )
				.attr( 'id', 'objective-type-' + objectiveAlias )
				.appendTo( $( '#inv-menu-objective-items' ) );
			
			$( '<div class="inv-menu-objective-item-title" />' )
				.text( objectiveInfo.title )
				.appendTo( itemElement );
				
			$( '<div class="inv-menu-objective-item-content" />' )
				.appendTo( itemElement )
				.append(
					$( '<div class="inv-menu-objective-item-content-line-wrap" />' )
						.append( '<div class="inv-menu-objective-item-content-line" />' ),
					$( '<div class="inv-menu-objective-item-content-value" />' )
						.text( '0 / ' + objectiveInfo.amount )
				)
		} );
	},
	
	// Установить состояние выполнения цели
	setObjectiveStatus : function( objectiveAlias, current, amount, total ) {
		var itemElement = $( '#objective-type-' + objectiveAlias );
		$( itemElement ).find( '.inv-menu-objective-item-content-line' ).css( 'width', ( ( current / amount ) * 100 ) + '%' );
		$( itemElement ).find( '.inv-menu-objective-item-content-value' ).text( current + ' / ' + amount );
	},
	
	// Установить состояние уровня (внизу списка целей)
	setTotalStatus : function( level, levelExp, nextLevelExp ) {
		$( '#inv-menu-objective-total-level' ).text( 'Уровень: ' + level );
		$( '#inv-menu-objective-total-exp' ).text( levelExp + ' / ' + nextLevelExp + ' xp' );
		$( '#inv-menu-objective-total-line' ).css( 'width', ( levelExp / nextLevelExp * 100 ) + '%' );
	}
}
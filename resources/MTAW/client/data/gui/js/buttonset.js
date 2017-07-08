"use strict";
var Buttonset = {
	init : function() {
		// Существующие buttonset'ы
		$( '.buttonset .button' ).bind( 'click', function( e ) {
			Buttonset.onClick( this );
		} );
		
		// Новые (при создании новых buttonset'ов)
		$( document ).bind( 'DOMNodeInserted', function( e ) {
			if ( $( e.target ).is( '.buttonset' ) ) {
				$( e.target ).find( '.button' ).bind( 'click', function( e ) {
					Buttonset.onClick( this );
				} );
			}
		} );
	},
	
	onClick : function( buttonElement ) {
		var parent = $( buttonElement ).parent();
		$( parent ).attr( 'value', $( buttonElement ).attr( 'value' ) );
		$( parent ).find( '.button' ).removeClass( 'active' );
		$( buttonElement ).addClass( 'active' );
	}
};
$( document ).ready( Buttonset.init );
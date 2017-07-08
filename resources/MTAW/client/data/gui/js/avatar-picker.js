(function( $ ){
	var methods = {
		
		init : function( options ) {
			var settings = $.extend( {
				'size'         : 'small'
			}, options );
	
			return this.each( function() {
				var $this = $( this ),
					data = $this.data( 'avatarPicker' );
				
				var picker = $( '<div />' ).addClass( 'avatar-picker-menu' );
				
				if ( !data ) {
					// Еще не проинициализирован
					$this.data( 'avatarPicker', {
						target : $this,
						picker : picker
					} );
				}
			} );
		},
		
		destroy : function( ) {
			return this.each( function() {
				var $this = $( this ),
					data = $this.data( 'avatarPicker' );

				$( window ).unbind( '.avatarPicker' );
				data.avatarPicker.remove();
				$this.removeData( 'avatarPicker' );
			} );
		},
		
		update : function( content ) {
		
		};
	};

	$.fn.avatarPicker = function( method ) {
		if ( methods[ method ] ) {
			return methods[ method ].apply( this, Array.prototype.slice.call( arguments, 1 ) );
		} else if ( typeof method === 'object' || ! method ) {
			return methods.init.apply( this, arguments );
		} else {
			$.error( 'Метод с именем ' +  method + ' не существует для jQuery.avatarPicker' );
		}
	};
})( jQuery );
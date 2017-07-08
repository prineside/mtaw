"use strict";
var Model = {
	showLoading : function() {
		console.error( "showLoading" )
		$( '#model' ).stop().fadeIn();
	},
	
	hideLoading : function() {
		$( '#model' ).stop().fadeOut();
	},
	
	setStatus : function( status ) {
		$( '#model-status' ).html( status );
	},
	
	setProgress : function( progress ) {
		$( '#model-progress-line' ).css( 'width', progress + '%' );
	}
};
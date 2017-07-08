<?php
	$gd = imagecreatetruecolor( 256, 256 );
	
	for ( $x = 0; $x < 256; $x++ ) {
		for ( $y = 0; $y < 256; $y++ ) {
			$c = imagecolorallocate( $gd, $x, $y, 0 ); 
			imagesetpixel( $gd, $x, $y, $c );
		}
	}
	
	imagepng( $gd, 'uv.png' );
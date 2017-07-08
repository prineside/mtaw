<?php
	// Преобразует map.ser в map.json
	file_put_contents( 'map.json', json_encode( unserialize( file_get_contents( 'map.ser' ) ) ) );
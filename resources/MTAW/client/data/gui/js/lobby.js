"use strict";
var Lobby = {
	menuBlurID : null,
	
	lastSelectedCharacter : null,
	characters : null,
	isVisible : false,
	
	init : function() {
		
	},
	
	setVisible : function( setVisible ) {
		if ( typeof( setVisible ) == 'undefined' ) {
			setVisible = true;
		}
		
		if ( setVisible ) {
			$( '#lobby' ).addClass( 'visible' );
			$( 'body' ).addClass( 'lobby-visible' );
		} else {
			$( '#lobby' ).removeClass( 'visible' );
			$( 'body' ).removeClass( 'lobby-visible' );
		}
		Lobby.isVisible = setVisible;
	},
	
	// Установить список персонажей
	setCharacters : function( characterList ) {
		Lobby.characters = Object.create( null );
		
		$( '#lobby-character-list' ).html( '' );
		
		$.each( characterList, function( k, v ) {
			Lobby.characters[ v.id ] = v;
			
			var characterElement = $( '<div class="lobby-character" />' ).attr( "id", "lobby-character-" + v.id );
			$( characterElement ).on( 'click', function() {
				Lobby.selectCharacter( v.id );
			} );
			
			var characterStatus = "Бездействует";
			/*
			var rand = Math.floor(Math.random() * 6);
			if ( rand == 0 ) {
				characterStatus = 'Камера полиции ЛС';
			} else if ( rand == 1 ) {
				characterStatus = 'Камера полиции СФ';
			} else if ( rand == 2 ) {
				characterStatus = 'Реанимация клиники СФ';
			} else if ( rand == 3 ) {
				characterStatus = 'Реанимация клиники ЛВ';
			} else if ( rand == 4 ) {
				characterStatus = 'Следует: стоянка бездомных';
			} else {
				characterStatus = 'В доме ЛС-' + Math.floor(Math.random() * 500);
			}
			*/
			
			var avatarTemplateNumber = v.avatar.substring( 0, 1 );
			var avatarSegmentColors = v.avatar.substring( 1 );
			$( characterElement ).append( 
				$( '<div class="avatar" />' ).append(
					$( '<img />' ).attr( 'src', '../avatar/textures_small/' + avatarTemplateNumber + '/' + avatarSegmentColors + '.png' )
				),
				$( '<div class="info" />' ).append(
					$( '<div class="name" />' ).text( v.name + " " + v.surname ),
					$( '<div class="status" />' ).text( characterStatus )
				),
				$( '<div class="level" />' ).text( v.level )
			);
			$( '#lobby-character-list' ).append( characterElement );
		} );
		
		if ( Lobby.lastSelectedCharacter == null ) {
			// Последнего выбранного персонажа нет
			if ( Lobby.characters.length != 0 ) {
				// Персонажи есть, выделяем первого персонажа
				$.each( Lobby.characters, function( kk, vv ) {
					Lobby.lastSelectedCharacter = vv.id;
					return false;
				} );
			}
		} else {
			// Есть последний выбранный персонаж, ищем его в текущем списке
			if ( typeof( Lobby.characters[ Lobby.lastSelectedCharacter ] ) == "undefined" ) {
				// Персонаж уже не существует
				Lobby.lastSelectedCharacter = null;
				if ( Lobby.characters.length != 0 ) {
					// Персонажи есть, выделяем первого персонажа
					$.each( Lobby.characters, function( kk, vv ) {
						Lobby.lastSelectedCharacter = vv.id;
						return false;
					} );
				}
			}
		}
		
		Lobby.selectCharacter( Lobby.lastSelectedCharacter );
		
		$( '#lobby-character-list-update-button i.fa' ).removeClass( 'fa-spin' );
	},
	
	// Обновить список персонажей (запрос к серверу)
	updateCharacterList : function() {
		$( '#lobby-character-list-update-button i.fa' ).addClass( 'fa-spin' );
		Main.sendEvent( "Lobby.updateCharacterList" );
	},
 	 
	// Выбрать текущего персонажа в списке
	selectCharacter : function( characterID ) {
		if ( characterID == null || characterID == false ) {
			// Убрать персонажа
			$( '.lobby-character' ).removeClass( 'active' ); 
			Main.sendEvent( "Lobby.selectCharacter", false );
		} else {
			if ( typeof( Lobby.characters[ characterID ] ) != "undefined" ) {
				$( '.lobby-character' ).removeClass( 'active' ); 
				$( '#lobby-character-' + characterID ).addClass( 'active' );
				
				// Устанавливаем имя персонажа в заголовок панели характеристик
				$( '#lobby-character-info-title' ).text( Lobby.characters[ characterID ].name + " " + Lobby.characters[ characterID ].surname );
				
				Main.sendEvent( "Lobby.selectCharacter", characterID );
			} else {
				console.error( 'Ошибка - выбранный персонаж (' + characterID + ') не существует' );
			}
		}
		
		Lobby.lastSelectedCharacter = characterID;
	},
	
	// Выбрать текущего персонажа для входа в игру
	acceptCharacterSelection : function() {
		if ( Lobby.lastSelectedCharacter != null ) {
			Main.sendEvent( "Lobby.acceptCharacterSelection", Lobby.lastSelectedCharacter );
		} else {
			Popup.show( "Персонаж не выбран", "error" );
		}
	},
	
	// Установить информацию справа от персонажа
	setCharacterInfo : function( info ) {
		//console.log( "Установка данных персонажа:", info );
		if ( info == false ) {
			// Скрываем
			$( '#lobby-character-info' ).hide();
		} else {
			$( '#lobby-character-info-value-id' ).html( '<b>' + info.id + '</b>' );
			$( '#lobby-character-info-value-name' ).html( '<b>' + info.name + ' ' + info.surname + '</b>' );
			$( '#lobby-character-info-value-level' ).html( '( ' + info.levelExp + ' / ' + info.nextLevelExp + ' xp ) <b>' + info.level + '</b>' );
			$( '#lobby-character-info-value-money' ).html( '<i class="fa fa-money"></i><b>' + info.money + '</b><i class="fa fa-university"></i><b>' + info.bank + '</b>' );
			$( '#lobby-character-info-value-faction' ).html( '<b>Без фракции</b>' );
			
			$( '#lobby-character-info-bar-health' ).children( '.bar-line' ).animate( { width : info.health + '%' }, 200 );
			$( '#lobby-character-info-bar-health' ).children( 'span' ).text( Math.round( info.health ) );
			
			$( '#lobby-character-info-bar-armor' ).children( '.bar-line' ).animate( { width : info.armor + '%' }, 200 );
			$( '#lobby-character-info-bar-armor' ).children( 'span' ).text( Math.round( info.armor ) );
			
			$( '#lobby-character-info-bar-satiety' ).children( '.bar-line' ).animate( { width : info.satiety + '%' }, 200 );
			$( '#lobby-character-info-bar-satiety' ).children( 'span' ).text( Math.round( info.satiety ) );
			
			$( '#lobby-character-info-bar-immunity' ).children( '.bar-line' ).animate( { width : info.immunity + '%' }, 200 );
			$( '#lobby-character-info-bar-immunity' ).children( 'span' ).text( Math.round( info.immunity ) );
			
			$( '#lobby-character-info-bar-energy' ).children( '.bar-line' ).animate( { width : info.energy + '%' }, 200 );
			$( '#lobby-character-info-bar-energy' ).children( 'span' ).text( Math.round( info.energy ) );
			
			$( '#lobby-character-info' ).show();
		}
	}
};
$( document ).ready( function() {
	Lobby.init();
} );
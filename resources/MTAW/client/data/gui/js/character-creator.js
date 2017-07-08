"use strict";
var CharacterCreator = {
	isVisible : false,
	
	availableSkins : {},		// male => { model => name }, female => { ... }
	skinIndices : {},			// male => [ 0 => model, 1 => model... ], female => [ ... ]
	currentSkinIndex : {},		// male => 0, female => 0
	selectedGender : null,		
	
	femaleGenderWarningShown : false,	
	
	init : function() {
		$( '#character-creator-radio-gender' ).buttonset();
	},
	
	setVisible : function( isVisible ) {
		if ( typeof( isVisible ) == 'undefined' ) {
			isVisible = true;
		}
		
		if ( CharacterCreator.isVisible != isVisible ) {
			if ( isVisible ) {
				$( '#character-creator' ).addClass( 'visible' );
				
				// Если уже был выбран пол, показываем превью
				if ( $( '#character-creator-gender' ).attr( 'value' ) != undefined ) {
					CharacterCreator.onGenderSelected();
				}
			} else {
				$( '#character-creator' ).removeClass( 'visible' );
				
				// Скрываем диалог, вдруг есть
				GUI.hideDialog();
			}
			CharacterCreator.isVisible = isVisible;
		}
	},
	
	// Сообщить, что играет реально девушка (чтобы не показывалось предупреждение)
	// TODO
	setFemaleGenderConfirmed : function() {
		CharacterCreator.femaleGenderWarningShown = true;
	},
	
	setAvailableSkins : function( skins ) {
		CharacterCreator.availableSkins = skins;
		
		// Генерация индексных массивов (для выбора стрелками туда-сюда)
		var indices = {};
		$.each( skins, function( gender, skins ) {
			indices[ gender ] = [];
			CharacterCreator.currentSkinIndex[ gender ] = 0;
			
			$.each( skins, function( skinModel, skinName ) {
				indices[ gender ].push( skinModel );
			} );
		} );
		
		CharacterCreator.skinIndices = indices;
	},
	
	setSkinSelector : function( gender, skinIndex ) {
		var skinModel = CharacterCreator.skinIndices[ gender ][ skinIndex ];
		
		$( '#character-creator-skin-name' ).text( CharacterCreator.availableSkins[ gender ][ skinModel ] );
		
		// Обновляем превью
		Main.sendEvent( "CharacterCreator.setPreviewSkin", skinModel );
		
		CharacterCreator.currentSkinIndex[ gender ] = skinIndex;
	},
	
	setPreviousSkin : function() {
		if ( CharacterCreator.selectedGender != undefined ) {
			var gender = CharacterCreator.selectedGender;
			var idx = CharacterCreator.currentSkinIndex[ gender ] - 1;
			if ( idx < 0 ) {
				idx = CharacterCreator.skinIndices[ gender ].length - 1;
			}
			
			CharacterCreator.setSkinSelector( gender, idx );
		}
	},
	
	setNextSkin : function() {
		if ( CharacterCreator.selectedGender != undefined ) {
			var gender = CharacterCreator.selectedGender;
			var idx = CharacterCreator.currentSkinIndex[ gender ] + 1;
			if ( idx >= CharacterCreator.skinIndices[ gender ].length ) {
				idx = 0;
			}
			
			CharacterCreator.setSkinSelector( gender, idx );
		}
	},
	
	setSlotStatistic : function( slotStatistic ) {
		console.log( slotStatistic );
		
		$( '#character-creator-slot-statistic-label' ).text( 'Использовано слотов: ' + slotStatistic.used + ' из ' + slotStatistic.total );
			
		if ( slotStatistic.nextSlotExp == 0 ) {
			// Больше открыть слоты опытом нельзя
			$( '#character-creator-slot-statistic-line-wrap' ).hide();
			$( '#character-creator-slot-statistic-opened-all' ).show();
		} else {
			// Можно открыть слот опытом
			$( '#character-creator-slot-statistic-line-wrap' ).show();
			$( '#character-creator-slot-statistic-opened-all' ).hide();
			
			$( '#character-creator-slot-statistic-line-prev-exp' ).text( slotStatistic.prevSlotExp );
			$( '#character-creator-slot-statistic-line-next-exp' ).text( slotStatistic.nextSlotExp );
			$( '#character-creator-slot-statistic-line-current-exp' ).text( slotStatistic.totalExp );
			$( '#character-creator-slot-statistic-line' ).css( 'width', ( ( slotStatistic.totalExp - slotStatistic.prevSlotExp ) / ( slotStatistic.nextSlotExp - slotStatistic.prevSlotExp ) * 100 ) + 'px' );
		}
		
		if ( slotStatistic.used < slotStatistic.total ) {
			// Есть слоты
			$( '#character-creator-available-slot-contents' ).show();
			$( '#character-creator-not-available-slot-contents' ).hide();
			$( '#character-creator-create-button' ).show();
		} else {
			// Слотов нет
			$( '#character-creator-available-slot-contents' ).hide();
			$( '#character-creator-not-available-slot-contents' ).show();
			$( '#character-creator-create-button' ).hide();
		}
	},
	
	// Нажали на кнопку "Создать"
	confirmCreation : function() {
		var gender = $( '#character-creator-gender' ).attr( 'value' );
		if ( gender == undefined ) {
			// Пол не выбран
			Popup.show( "Сначала выберите пол персонажа", "error", "exclamation-triangle" );
			return false;
		}
		
		var name = $( '#character-creator-name' ).val();
		var surname = $( '#character-creator-surname' ).val();
		
		// Валидациия имени
		function isValidCharacterName( str ) {
			// Разрешено: Абв, Абв-Где, Абв-Где-Тель-Авив, Берта Мария Бендер-Бей
			var wordStart = true;
			var wordLength = 0;
			
			for ( var i = 0; i < str.length; i++ ) {
				var c = str.charAt( i );
				//console.log( c );
				if ( c.match(/[а-яёА-ЯЁ\-\ ]/) != null ) {
					
					// Буква или дефис
					var isBig = c.match(/[А-ЯЁ]/) != null;
					var isSmall = !isBig;
					var isHyphen = ( c == '-' );
					var isSpace = ( c == ' ' );
					
					if ( wordStart ) {
						// Начало слова - разрешена только большая буква
						if ( isSmall || isHyphen || isSpace ) {
							console.log( 'Начало слова: small = ', isSmall, ', big = ', isBig, ', hyphen = ', isHyphen, ', space = ', isSpace );
							return false;
						}
						wordLength = 1;
						wordStart = false;
					} else {
						// Не начало слова - только маленькая либо дефис или пробел
						if ( !( isHyphen || isSmall || isSpace ) ) {
							console.log( 'В средине слова: small = ', isSmall, ', big = ', isBig, ', hyphen = ', isHyphen, ', space = ', isSpace );
							return false;
						}
						if ( isHyphen || isSpace ) {
							// Дефис или пробел - начало слова
							if ( wordLength < 2 ) {
								// В предыдущем слове меньше 2 символов
								console.log( 'Короткое слово перед дефисом или пробелом: small = ', isSmall, ', big = ', isBig, ', hyphen = ', isHyphen, ', wordLength = ', wordLength, ', space = ', isSpace );
								return false;
							}
							
							wordStart = true;
							wordLength = 0;
						} else {
							// Маленькая буква
							wordLength++;
						}
					}
				} else {
					// Другое
					console.log( 'Не буква, пробел или дефис' );
					return false;
				}
			}
			
			return !wordStart;	// Если начало слова (т.е. последним был дефис или пустая строка)
		}
		
		if ( name.length < 2 ) {
			// Короткое имя
			Popup.show( "Слишком короткое имя", "error", "exclamation-triangle" );
			return false;
		} else if ( name.length >= 24 ) {
			// Длинное имя
			Popup.show( "Слишком длинное имя", "error", "exclamation-triangle" );
			return false;
		}
		
		if ( surname.length < 2 ) {
			// Короткая фамилия
			Popup.show( "Слишком короткая фамилия", "error", "exclamation-triangle" );
			return false;
		} else if ( surname.length >= 24 ) {
			// Длинная фамилия
			Popup.show( "Слишком длинная фамилия", "error", "exclamation-triangle" );
			return false;
		}
		
		if ( !isValidCharacterName( name ) ) {
			Popup.show( "Неправильный формат имени. Имя должно начинаться с большой буквы, содержать только русские символы или дефис. Например: \"Алексей\", \"Остап-Сулейман\"", "error", "exclamation-triangle", 8000 );
			return false;
		}
		
		if ( !isValidCharacterName( surname ) ) {
			Popup.show( "Неправильный формат фамилии. Фамилия должна начинаться с большой буквы, содержать только русские символы, пробел или дефис. Например: \"Сидоров\", \"Берта Бендер-Бей\"", "error", "exclamation-triangle", 8000 );
			return false;
		}
		
		var skinModel = CharacterCreator.skinIndices[ gender ][ CharacterCreator.currentSkinIndex[ gender ] ];
		
		Main.sendEvent( "CharacterCreator.createCharacter", name, surname, gender, skinModel );
	},
	
	// Игрок выбрал пол
	onGenderSelected : function() {
		// Узнаем, какой пол выбран
		var gender = $( '#character-creator-gender' ).attr( 'value' );
		
		if ( gender == undefined ) {
			console.error( 'Пол не выбран' );
			
			// Скрываем выбор скина
			$( '#character-creator-skin-selector' ).show();
		} else {
			CharacterCreator.selectedGender = gender;
		
			// Изменяем выбор скина
			CharacterCreator.setSkinSelector( gender, CharacterCreator.currentSkinIndex[ gender ] );
			
			// Показываем выбор скина
			$( '#character-creator-skin-selector' ).show();
			
			// Если выбран женский пол, показываем предупреждение
			if ( gender == 'female' && !CharacterCreator.femaleGenderWarningShown ) {
				GUI.showDialog( "Персонажи женского пола будут отмечены как неподтвержденные и не вызовут доверия у игроков. Вы можете подтвердить свой пол в личном кабинете на сайте prineside.com, чтобы получить подтверждающую отметку и доверие со стороны игроков", "exclamation-triangle", [
					$( '<div class="button button-float-right" />' )
						.html( '<i class="fa fa-check"></i>Ознакомлен(а)' )
						.on( 'click', function() { GUI.hideDialog(); } )
				] );
				CharacterCreator.femaleGenderWarningShown = true;
			}
		}
	}
};
$( document ).ready( CharacterCreator.init );
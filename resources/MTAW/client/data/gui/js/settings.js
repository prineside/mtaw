"use strict";
var Settings = {
	template : {},
	cfg : {},
	
	cfgChanged : false,
	
	isVisible : false,
	
	init : function() {
		// Бинд кнопки закрытия настроек
		$( '#settings-button-cancel' ).on( 'click', function() {
			if ( Settings.cfgChanged ) {
				GUI.showDialog( 'Настройки изменены, отменить изменения и закрыть окно настроек?', 'question', [
					$( '<div class="button button-float-left" />' )
						.html( '<i class="fa fa-times"></i>Нет' )
						.on( 'click', GUI.hideDialog ),
						
					$( '<div class="button button-float-right" />' )
						.html( '<i class="fa fa-check"></i>Да' )
						.on( 'click', function() {
							Main.sendEvent( 'Settings.toggleVisible' );
							GUI.hideDialog();
						} )
				] );
			} else {
				Main.sendEvent( 'Settings.toggleVisible' );
			}
		} );
		
		// Бинд кнопки сброса настроек
		$( '#settings-button-defaults' ).on( 'click', function() {
			GUI.showDialog( 'Установить стандартные настройки?', 'undo', [
				$( '<div class="button red button-float-left" />' )
					.html( '<i class="fa fa-times"></i>Отмена' )
					.on( 'click', GUI.hideDialog ),
					
				$( '<div class="button button-float-right" />' )
					.html( '<i class="fa fa-undo"></i>Сброс настроек' )
					.on( 'click', function() {
						Settings.setDefaults();
						GUI.hideDialog();
					} )
			] );
		} );
	},
	
	setCfgChanged : function( isChanged ) {
		Settings.cfgChanged = isChanged;
		if ( isChanged ) {
			$( '#settings-button-accept' ).addClass( 'green' ).removeClass( 'grey' );
		} else {
			$( '#settings-button-accept' ).removeClass( 'green' ).addClass( 'grey' );
		}
	},
	
	setVisible : function( isVisible ) {
		if ( typeof( isVisible ) == 'undefined' ) {
			isVisible = true;
		}
		
		if ( Settings.isVisible != isVisible ) {
			if ( isVisible ) {
				$( '#settings' ).addClass( 'visible' );
				
				// Показываем первую категорию, если не была выбрана другая ранее
				if ( $( '.settings-tab.active' ).length == 0 ) {
					var firstCategory = null;
					$.each( $( '.settings-tab-header' ), function( k, v ) {
						firstCategory = $( v ).attr( 'data-categoryName' );
						return false;
					} );
					
					Settings.setTab( firstCategory );
				}
			} else {
				$( '#settings' ).removeClass( 'visible' );
				
				// Скрываем диалог, вдруг есть
				GUI.hideDialog();
			}
			Settings.isVisible = isVisible;
		}
	},
	
	// Открыть вкладку настроек
	setTab : function( categoryName ) {
		$( '.settings-tab-header' ).removeClass( 'active' );
		$( '.settings-tab' ).removeClass( 'active' );
		
		$( '#settings-tab-header-' + categoryName ).addClass( 'active' );
		$( '#settings-tab-' + categoryName ).addClass( 'active' );
	},
	
	// Устанавливает значение настройки
	setValue : function( categoryAlias, itemAlias, value, initSet ) {
		if ( initSet == undefined ) {
			initSet = false;
		} else {
			initSet = true;
		}
		
		var itemData = Settings.template[ categoryAlias ].items[ itemAlias ];
		if ( itemData.type == "int" ) {
			// int
			// Установка в допустимых границах
			value = parseInt( value );
			if ( itemData.min > value ) {
				value = parseInt( itemData.min );
			} else if ( itemData.max < value ) {
				value = parseInt( itemData.max );
			}
			
			// Устанавливаем позицию слайдера
			var slider = $( '#settings-item-' + categoryAlias + '-' + itemAlias ).children( '.settings-item-value-slider' ).eq( 0 );
			var thumb = $( slider ).children( '.settings-item-value-slider-thumb' ).eq( 0 );
			var sliderMaxPosition = 300 - $( thumb ).width();
			var coeff = ( value - itemData.min ) / ( itemData.max - itemData.min );
			$( thumb ).css( 'left', ( coeff * sliderMaxPosition ) + "px" );
			
			// Устанавливаем input
			$( '#settings-item-input-' + categoryAlias + '-' + itemAlias ).val( value );
		} else if ( itemData.type == "float" ) {
			// float
			// Установка в допустимых границах
			value = parseFloat( value );
			if ( itemData.min > value ) {
				value = parseFloat( itemData.min );
			} else if ( itemData.max < value ) {
				value = parseFloat( itemData.max );
			}
			
			// Устанавливаем позицию слайдера
			var slider = $( '#settings-item-' + categoryAlias + '-' + itemAlias ).children( '.settings-item-value-slider' ).eq( 0 );
			var thumb = $( slider ).children( '.settings-item-value-slider-thumb' ).eq( 0 );
			var sliderMaxPosition = 300 - $( thumb ).width();
			var coeff = ( value - itemData.min ) / ( itemData.max - itemData.min );
			$( thumb ).css( 'left', ( coeff * sliderMaxPosition ) + "px" );
			
			// Устанавливаем input
			$( '#settings-item-input-' + categoryAlias + '-' + itemAlias ).val( value );
		} else if ( itemData.type == "bool" ) {
			// bool
			if ( value == true || value == "true" ) {
				value = true;
			} else if ( value == false || value == "false" ) {
				value = false;
			} else {
				console.error( "Value должно быть true или false" );
			}
			
			// Устанавливаем input
			$( '#settings-item-input-' + categoryAlias + '-' + itemAlias ).prop( "checked", value );
		} else if ( itemData.type == "string" ) {
			// string
			$( '#settings-item-input-' + categoryAlias + '-' + itemAlias ).children( "option" ).attr( "selected", "false" );
			$( '#settings-item-input-' + categoryAlias + '-' + itemAlias ).children( "option[value=" + value + "]" ).attr( "selected", "true" );
			
			$( '#settings-item-input-' + categoryAlias + '-' + itemAlias ).val( value );
			
			if ( initSet ) {
				$( '#settings-item-input-' + categoryAlias + '-' + itemAlias ).trigger( 'change' );
			}
		}
		
		Settings.cfg[ categoryAlias ][ itemAlias ] = value;
	},
	
	// Получить текущее значение настройки
	getValue : function( categoryAlias, itemAlias ) {
		if ( Settings[ categoryAlias ] != undefined ) {
			if ( Settings[ categoryAlias ][ itemAlias ] != undefined ) { 
				return Settings[ categoryAlias ][ itemAlias ];
			} else {
				return null;
			}
		} else {
			return null;
		}
	},
	
	// Отправить запрос на сохоанение настроек
	save : function() {
		Main.sendEvent( "Settings.save", Settings.cfg )
		Settings.setCfgChanged( false );
	},
	
	// Установить стандартные настройки
	setDefaults : function() {
		$.each( Settings.cfg, function( categoryAlias, categoryItems ) {
			$.each( categoryItems, function( itemAlias, itemValue ) {
				Settings.setValue( categoryAlias, itemAlias, Settings.template[ categoryAlias ].items[ itemAlias ].default, true );
			} );
		} );
		Settings.save();
	},
	
	// Установить значения настроек
	setConfiguration : function( cfg ) {
		Settings.cfg = cfg;
		//console.log( cfg );
		
		$.each( cfg, function( categoryAlias, categoryItems ) {
			$.each( categoryItems, function( itemAlias, itemValue ) {
				Settings.setValue( categoryAlias, itemAlias, itemValue, true );
			} );
		} );
		
		Settings.setCfgChanged( false );
	},
	
	// Установить шаблон настроек (массив категорий и параметров для отображения)
	setTemplate : function( template ) {
		//console.log( "Пришел новый шаблон настроек", template );
		
		Settings.template = template;

		$( '#settings-header-tabs' ).html( '' );
		$( '#settings-content' ).html( '' );
		
		$.each( template, function( categoryAlias, categoryData ) {
			// Проверяем, есть ли в категории пункты, которые можно настроить
			var haveItems = false;
			$.each( categoryData.items, function( itemAlias, itemData ) {
				if ( itemData.setting ) {
					haveItems = true;
					return false;
				}
			} );
			
			if ( haveItems ) {
				// Заголовок вкладки
				var tabHeader = $( '<div class="settings-tab-header" />' )
					.attr( 'id', 'settings-tab-header-' + categoryAlias )
					.attr( 'data-categoryName', categoryAlias )
					.bind( 'click', function() {
						Settings.setTab( $( this ).attr( 'data-categoryName' ) );
					} )
					.html( categoryData.name )
					.appendTo( $( '#settings-header-tabs' ) );
				
				// Содержимое вкладки
				var tabContent = $( '<div class="settings-tab" />' )
					.attr( 'id', 'settings-tab-' + categoryAlias )
					.appendTo( $( '#settings-content' ) );
				
				// Элементы вкладки
				$.each( categoryData.items, function( itemAlias, itemData ) {
					if ( itemData.setting ) {
						var item = $( '<div class="settings-item" />' )
							.addClass( 'item-type-' + itemData.type )
							.appendTo( tabContent )
							.append(
								$( '<div class="settings-item-name" />' )
									.attr( 'title', itemData.description )
									.html( itemData.name )
							);
						
						var itemValue = $( '<div class="settings-item-value" />' )
							.attr( 'id', 'settings-item-' + categoryAlias + '-' + itemAlias )
							.appendTo( item );
							
						if ( itemData.type == "int" ) {
							// int - слайдер и input сбоку
							// Создаем слайдер
							var slider = $( '<div class="settings-item-value-slider" />' )
								.appendTo( itemValue );
							
							var sliderHandle = $( '<div class="settings-item-value-slider-thumb" />' )
								.appendTo( slider );
							
							// Создаем input и добавляем кнопку сброса
							var sliderInput = $( '<input class="settings-item-value-slider-input" />' )
								.attr( 'id', 'settings-item-input-' + categoryAlias + '-' + itemAlias )
								.appendTo( itemValue )
								.bind( 'keydown blur', function( e ) {
									if ( e.type == "blur" || e.which == 13 ) {
										Settings.setValue( categoryAlias, itemAlias, $( sliderInput ).val() );
										Settings.setCfgChanged( true );
									}
								} );
								
							$( '<button class="settings-item-default-button" />' )
								.attr( 'title', 'Установить стандартное значение' )
								.html( '<i class="fa fa-undo"></i>' )
								.appendTo( itemValue )
								.on( "click", function( e ) {
									Settings.setValue( categoryAlias, itemAlias, itemData.default );
									Settings.setCfgChanged( true );
								} );
							
							// Обработка перетаскивания слайдера
							$( sliderHandle ).draggable( {
								axis: "x",
								containment: "parent",
								drag: function( event, ui ) {
									var sliderMaxPosition = 300 - $( sliderHandle ).width();
									var coeff = ui.position.left / sliderMaxPosition;
									
									$( sliderInput ).val( Math.round( itemData.min + coeff * ( itemData.max - itemData.min ) ) );
								},
								stop: function( event, ui ) {
									var sliderMaxPosition = 300 - $( sliderHandle ).width();
									var coeff = ui.position.left / sliderMaxPosition;
									
									Settings.setCfgChanged( true );
									Settings.setValue( categoryAlias, itemAlias, Math.round( itemData.min + coeff * ( itemData.max - itemData.min ) ) );
								}
							} );
						} else if ( itemData.type == "float" ) {
							// float - слайдер и input сбоку
							// Создаем слайдер
							var slider = $( '<div class="settings-item-value-slider" />' )
								.appendTo( itemValue );
							
							var sliderHandle = $( '<div class="settings-item-value-slider-thumb" />' )
								.appendTo( slider );
							
							// Создаем input и добавляем кнопку сброса
							var sliderInput = $( '<input class="settings-item-value-slider-input" />' )
								.attr( 'id', 'settings-item-input-' + categoryAlias + '-' + itemAlias )
								.appendTo( itemValue )
								.bind( 'keydown blur', function( e ) {
									if ( e.type == "blur" || e.which == 13 ) {
										Settings.setValue( categoryAlias, itemAlias, $( sliderInput ).val() );
										Settings.setCfgChanged( true );
									}
								} );
								
							$( '<button class="settings-item-default-button" />' )
								.attr( 'title', 'Установить стандартное значение' )
								.html( '<i class="fa fa-undo"></i>' )
								.appendTo( itemValue )
								.on( "click", function( e ) {
									Settings.setValue( categoryAlias, itemAlias, itemData.default );
									Settings.setCfgChanged( true );
								} );
							
							// Обработка перетаскивания слайдера
							$( sliderHandle ).draggable( {
								axis: "x",
								containment: "parent",
								drag: function( event, ui ) {
									var sliderMaxPosition = 300 - $( sliderHandle ).width();
									var coeff = ui.position.left / sliderMaxPosition;
									
									$( sliderInput ).val( Number( itemData.min + coeff * ( itemData.max - itemData.min ) ).toPrecision( itemData.precision ) );
								},
								stop: function( event, ui ) {
									var sliderMaxPosition = 300 - $( sliderHandle ).width();
									var coeff = ui.position.left / sliderMaxPosition;
									
									Settings.setCfgChanged( true );
									Settings.setValue( categoryAlias, itemAlias, Number( itemData.min + coeff * ( itemData.max - itemData.min ) ).toPrecision( itemData.precision ) );
								}
							} );
						} else if ( itemData.type == "bool" ) {
							// bool - флажок
							
							// Создаем input checkbox
							var sliderInput = $( '<input class="settings-item-value-checkbox-input" type="checkbox" />' )
								.attr( 'id', 'settings-item-input-' + categoryAlias + '-' + itemAlias )
								.appendTo( itemValue )
								.bind( 'click', function( e ) {
									Settings.setValue( categoryAlias, itemAlias, $( this ).prop( 'checked' ) );
									Settings.setCfgChanged( true );
								} );
							
							// Кнопка сброса
							$( '<button class="settings-item-default-button" />' )
								.attr( 'title', 'Установить стандартное значение' )
								.html( '<i class="fa fa-undo"></i>' )
								.appendTo( itemValue )
								.on( "click", function( e ) {
									Settings.setValue( categoryAlias, itemAlias, itemData.default );
									Settings.setCfgChanged( true );
								} );
						} else if ( itemData.type == "string" ) {
							// string - строка
							/*
								itemData:
								bestPerformance: "less"
								default: "medium"
								description: "При большом размере потребляется больше видеопамяти и текстуры генерируются дольше при первой их загрузке, но выглядят более качественно"
								max: false
								min: false
								name: "Размер текстур винилов машин"
								needRestart: true
								options: Object
								high: "Большой (2048x2048)"
								low: "Малый (512x512)"
								medium: "Средний (1024x1024)"
								__proto__: Object
								setting: true
								type: "string"
							*/
							
							// Создаем select
							var selectBox = $( '<select class="settings-item-value-select" />' )
								.attr( 'id', 'settings-item-input-' + categoryAlias + '-' + itemAlias )
								.appendTo( itemValue );
							
							// Добавляем options
							$.each( itemData.options, function( k, v ) {
								$( '<option />' ).attr( 'value', k ).html( v ).appendTo( selectBox );
							} );
							
							// Биндим
							selectBox.bind( 'change', function( e ) {
								console.log( e, $( this ).val() );
								Settings.setValue( categoryAlias, itemAlias, $( this ).val() );
								Settings.setCfgChanged( true );
							} );
							
							selectBox.select2({
								minimumResultsForSearch: Infinity
							});
						}
					}
				} );
			}
		} );
	}
};
$( document ).ready( Settings.init );
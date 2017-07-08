"use strict";
var Chat = {
	input : null,
	
	messageIndex : 1,
	
	historySize : 20,	// Размер истории последних введенных команд
	history : {},		// Сама история
	historyPtr : 0,		// Текущий указатель в истории (сюда будут добавляться новые сообщения)
	historyViewPtr : 0,	// Текущий указатель просмотра истории
	
	scrollShift : 0,
	disableScroll : false,
	
	init : function() {
		Chat.input = $( '#chat-input input' );
		
		$( '#chat-lines' ).on( 'mouseover', function() {
			Chat.disableScroll = true;
		} );
		$( '#chat-lines' ).on( 'mouseleave', function() {
			Chat.disableScroll = false;
		} );
		$( '#chat-lines' ).on( 'scroll', function() {
			Chat.scrollShift = $( '#chat-lines' )[0].scrollHeight - $( '#chat-lines' ).height() - $( '#chat-lines' ).scrollTop();
			if ( Chat.scrollShift == 0 ) {
				$( '#chat' ).removeClass( 'scrolled' );
			} else {
				$( '#chat' ).addClass( 'scrolled' );
			}
		} );
		// Нажатие на Enter
		Chat.input.on( 'keydown', function( e ) {
			if ( e.which == 13 ) {
				Chat.send( $( this ).val() );
			}
		} );
		
		// История (стрелка вверх и вниз)
		Chat.input.on( 'keydown', function( e ) {
			if ( e.which == 38 ) {
				// Стрелка вверх (предыдущее в истории)
				if ( Chat.history[ Chat.historyViewPtr - 1 ] != undefined ) {
					Chat.historyViewPtr--;
					Chat.input.val( Chat.history[ Chat.historyViewPtr ] );
					Chat.input.selectRange( Chat.history[ Chat.historyViewPtr ].length );
					e.preventDefault();
					return false;
				}
			} else if ( e.which == 40 ) {
				// Стрелка вниз (следующее в истории)
				if ( Chat.history[ Chat.historyViewPtr + 1 ] != undefined ) {
					Chat.historyViewPtr++;
					Chat.input.val( Chat.history[ Chat.historyViewPtr ] );
					Chat.input.selectRange( Chat.history[ Chat.historyViewPtr ].length );
					e.preventDefault();
					return false;
				}
			}
		} );
		
		// TODO бинд на колесико мышки за границами чата, чтобы прокручивать чат когда он активен, но курсор не на чате
	},
	
	messageTypeIcons : {
		state : 'newspaper-o',
		normal : 'comment',
		shout : 'comment',
		whisper : 'comment',
		warning : 'exclamation-triangle',
		error : 'exclamation-triangle',
		info : 'info-circle',
		radio : 'volume-up',
		success : 'check',
		broadcast : 'bullhorn'
	},
	
	messageTypeInfo : {
		state : 'Гос. новости',
		normal : 'Голос',
		shout : 'Крик',
		whisper : 'Шепот',
		warning : null,
		error : null,
		info : null,
		success : null,
		radio : 'Радио',
		broadcast : 'Общий чат'
	},
	
	addMessage : function( type, info, content, infoColor, contentColor, escapeHTML ) {
		if ( escapeHTML != true ) {
			escapeHTML = false;
		}
		var messageElement = $( '<div class="new" />' ).attr( 'id', 'chat-line-' + Chat.messageIndex ).addClass( type );
		$( messageElement ).append( '<i class="fa fa-' + Chat.messageTypeIcons[ type ] + '"></i>' );
		$( messageElement ).on( 'click', function() {
			$( this ).toggleClass( 'opened' );
		} );
		
		var messageInfoElement = $( '<span class="info" />' ).text( info ).appendTo( messageElement );
		if ( typeof( infoColor ) != 'undefined' ) {
			$( messageInfoElement ).css( 'color', infoColor );
		}
		
		if ( Chat.messageTypeInfo[ type ] ) {
			var infoDescriptionElement = $( '<span />' ).addClass( 'description' ).text( Chat.messageTypeInfo[ type ] ).appendTo( messageInfoElement );
			$( infoDescriptionElement ).prepend( '<span class="time">11:22:33</span>' );
		}
		
		var messageContentElement = $( '<span class="content" />' ).appendTo( messageElement );
		if ( escapeHTML ) {
			messageContentElement.text( content );
		} else {
			messageContentElement.html( content );
		}
		
		if ( typeof( contentColor ) != 'undefined' ) {
			$( messageContentElement ).css( 'color', contentColor );
		}
		
		$( '#chat-lines' ).append( messageElement );
		
		setTimeout( function() {
			$( messageElement ).addClass( 'not-new' );
		}, 1 );
		
		$( '#chat-line-' + ( Chat.messageIndex - 50 ) ).remove();
		
		Chat.scrollToBottom();
		Chat.messageIndex++;
	},
	
	setVisible : function( setVisible ) {
		if ( typeof( setVisible ) == 'undefined' ) {
			setVisible = true;
		}
		
		if ( setVisible ) {
			$( '#chat' ).addClass( 'visible' );
		} else {
			$( '#chat' ).removeClass( 'visible' );
		}
	}, 
	
	setActive : function( setActive ) {
		if ( typeof( setActive ) == 'undefined' ) {
			setActive = true;
		}
		
		if ( setActive ) {
			$( '#chat' ).addClass( 'active' );
			Chat.input.focus();
			Chat.input.selectRange( 0 );
		} else {
			$( '#chat' ).removeClass( 'active' );
		}
	},
	
	// Отправить содержимое поля под чатом (при нажатии Enter, например)
	send : function( msg ) {
		// Отправка события
		Main.sendEvent( "Chat.onChatSubmit", msg );
		
		// Очистка поля
		Chat.input.val( '' );
		
		// Добавление сообщения в историю
		if ( Chat.history[ Chat.historyPtr - 1 ] != msg ) {
			Chat.history[ Chat.historyPtr ] = msg;
			Chat.historyPtr++;
			
			if ( Chat.history[ Chat.historyPtr - Chat.historySize - 1 ] != undefined ) {
				delete Chat.history[ Chat.historyPtr - Chat.historySize - 1 ];
			}
		}
		
		Chat.historyViewPtr = Chat.historyPtr;
	},
	
	scrollToBottom : function() {
		if ( !Chat.disableScroll ) {
			$( '#chat-lines' ).scrollTop( $( '#chat-lines' )[0].scrollHeight - $( '#chat-lines' ).height() - Chat.scrollShift );
		}
	}
};
$( document ).ready( function() {
	Chat.init();
} );
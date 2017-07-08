-- --------------------------------------------------------
-- Сервер:                       127.0.0.1
-- Версія сервера:               5.6.20 - MySQL Community Server (GPL)
-- ОС сервера:                   Win64
-- HeidiSQL Версія:              9.3.0.4984
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- --------------------------------------------------------
-- Хост:                         127.0.0.1
-- Версия сервера:               5.7.18-0ubuntu0.16.04.1 - (Ubuntu)
-- Операционная система:         Linux
-- HeidiSQL Версия:              9.4.0.5125
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Дамп структуры для таблица mtaw.accounts
CREATE TABLE IF NOT EXISTS `accounts` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `login` varchar(50) NOT NULL,
  `tester` int(10) unsigned NOT NULL DEFAULT '0',
  `hash` char(32) NOT NULL,
  `blowfish` char(16) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `login` (`login`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

-- Дамп данных таблицы mtaw.accounts: ~0 rows (приблизительно)
/*!40000 ALTER TABLE `accounts` DISABLE KEYS */;
INSERT INTO `accounts` (`id`, `login`, `tester`, `hash`, `blowfish`) VALUES
	(1, 'admin', 1, 'bc7510d08ea7bb50cbb1e1b01fc16b8d', 'Fj5q3Y9xwrPDHo4V');
/*!40000 ALTER TABLE `accounts` ENABLE KEYS */;

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;

-- Dumping structure for таблиця mtaw.account_permission
CREATE TABLE IF NOT EXISTS `account_permission` (
  `account` int(11) NOT NULL,
  `permission` varchar(32) NOT NULL,
  KEY `FK_account_permission_permission` (`permission`),
  KEY `account` (`account`),
  CONSTRAINT `FK_account_permission_permission` FOREIGN KEY (`permission`) REFERENCES `permission` (`alias`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Права отдельных аккаунтов';

-- Dumping data for table mtaw.account_permission: ~0 rows (приблизно)
/*!40000 ALTER TABLE `account_permission` DISABLE KEYS */;
INSERT INTO `account_permission` (`account`, `permission`) VALUES
	(1, 'developer'),
	(1, 'vehicleSpawn'),
	(1, 'damage'),
	(1, 'giveItem'),
	(1, 'attachments'),
	(1, 'vehicleHandling');
/*!40000 ALTER TABLE `account_permission` ENABLE KEYS */;


-- Dumping structure for таблиця mtaw.avatar_names
CREATE TABLE IF NOT EXISTS `avatar_names` (
  `character` int(11) NOT NULL COMMENT 'Персонаж, который назначил имя',
  `avatar` varchar(16) NOT NULL COMMENT 'Аватар, которому было назначено имя',
  `name` varchar(64) NOT NULL COMMENT 'Назначенное имя',
  `date` int(11) NOT NULL COMMENT 'Время, когда было назначено имя',
  KEY `avatar` (`avatar`),
  KEY `FK_avatar_names_character` (`character`),
  CONSTRAINT `FK_avatar_names_character` FOREIGN KEY (`character`) REFERENCES `character` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_avatar_names_character_2` FOREIGN KEY (`avatar`) REFERENCES `character` (`avatar`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Назначенные игроками имена для аватарок других игроков';

-- Dumping structure for таблиця mtaw.character
CREATE TABLE IF NOT EXISTS `character` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account` int(11) NOT NULL,
  `x` float NOT NULL,
  `y` float NOT NULL,
  `z` float NOT NULL,
  `angle` float NOT NULL,
  `name` varchar(24) NOT NULL,
  `surname` varchar(24) NOT NULL,
  `money` int(11) unsigned NOT NULL DEFAULT '0',
  `dimension_name` varchar(32) NOT NULL DEFAULT 'Global',
  `dimension_id` varchar(32) NOT NULL DEFAULT '0',
  `gender` varchar(16) NOT NULL,
  `created` int(11) NOT NULL,
  `experience` int(11) NOT NULL DEFAULT '0',
  `satiety` float NOT NULL DEFAULT '100',
  `health` float NOT NULL DEFAULT '100',
  `armor` float NOT NULL DEFAULT '0',
  `immunity` int(11) NOT NULL DEFAULT '80',
  `energy` float NOT NULL DEFAULT '100',
  `bank` int(11) NOT NULL DEFAULT '0',
  `skin` int(11) NOT NULL DEFAULT '170',
  `avatar` varchar(16) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `avatar` (`avatar`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8 COMMENT='Персонаж';

-- Dumping structure for таблиця mtaw.inventory
CREATE TABLE IF NOT EXISTS `inventory` (
  `character_id` int(11) NOT NULL COMMENT 'ID персонажа',
  `container_type` varchar(32) NOT NULL COMMENT 'Тип слота (инвентарь, быстрый доступ...)',
  `slot_id` int(11) NOT NULL COMMENT 'Номер слота определенного типа',
  `class` varchar(32) NOT NULL COMMENT 'Класс вещи (из item_classes.lua)',
  `params` text NOT NULL COMMENT 'Параметры вещи в виде строки JSON',
  `count` int(11) NOT NULL COMMENT 'Количество вещей',
  PRIMARY KEY (`character_id`,`container_type`,`slot_id`),
  KEY `character` (`character_id`),
  CONSTRAINT `FK_inventory_character` FOREIGN KEY (`character_id`) REFERENCES `character` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Вещи в инвентарях';

-- Dumping structure for таблиця mtaw.model
CREATE TABLE IF NOT EXISTS `model` (
  `model` int(11) NOT NULL,
  `date` int(11) NOT NULL,
  `comment` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`model`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Список моделей, которые будут заменяться на клиенте.\r\nТаблица используется для того, чтобы сообщить о файлах, которые есть (так как MTA не позволяет считывать папки) и какие конкретно модели стоит изменять.\r\nТакже используется дата поседнего изменения модели (поле date) для замены моделей в процессе работы сервера (сервер периодически ищет в таблице модели, которые изменились после последнего обновления и обновляет файлы на клиентах)';

-- Dumping data for table mtaw.model: ~8 rows (приблизно)
/*!40000 ALTER TABLE `model` DISABLE KEYS */;
INSERT INTO `model` (`model`, `date`, `comment`) VALUES
	(411, 1456952503, 'Infernus'),
	(567, 1456316513, 'Savanna'),
	(5369, 1456328434, 'Сфера RaycastTarget (1.0м)'),
	(5370, 1456317149, 'Сфера RaycastTarget (0.5м)'),
	(5373, 1456952545, 'Сфера RaycastTarget (0.25м)'),
	(5374, 1456316693, 'Яблоко (предмет)'),
	(5375, 1456316664, 'Пучок пшеницы (предмет)'),
	(5844, 1456316553, 'Хлеб (предмет)');
/*!40000 ALTER TABLE `model` ENABLE KEYS */;


-- Dumping structure for таблиця mtaw.objective
CREATE TABLE IF NOT EXISTS `objective` (
  `type` varchar(50) NOT NULL,
  `character` int(11) NOT NULL,
  `current` int(11) NOT NULL DEFAULT '0' COMMENT 'Текущий статус выполнения цели',
  `total` int(11) NOT NULL DEFAULT '0' COMMENT 'Суммарный статус выполнения цели, а также статистика игрока',
  `exp_given` int(11) NOT NULL DEFAULT '0' COMMENT 'Сколько опыта было выдано игроку за выполнение этой цели за все время',
  PRIMARY KEY (`type`,`character`),
  KEY `FK_experience_character` (`character`),
  CONSTRAINT `FK_experience_character` FOREIGN KEY (`character`) REFERENCES `character` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_experience_experience_source` FOREIGN KEY (`type`) REFERENCES `objective_type` (`alias`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Цели (задачи), которые должен выполнять игрок, чтобы получать уровень';

-- Dumping structure for таблиця mtaw.objective_type
CREATE TABLE IF NOT EXISTS `objective_type` (
  `alias` varchar(50) NOT NULL COMMENT 'Алиас действия',
  `title` varchar(128) DEFAULT NULL COMMENT 'Название действия (вкратце)',
  `description` varchar(256) DEFAULT NULL COMMENT 'Описание действия (подробнее)',
  `amount` int(11) NOT NULL DEFAULT '1' COMMENT 'Сколько нужно очков действий, чтобы получить experience и сбросить счетчик на 0',
  `experience` int(11) NOT NULL DEFAULT '0' COMMENT 'Сколько опыта дает выполнение amount действий',
  `enabled` int(11) NOT NULL DEFAULT '1' COMMENT 'Если 1, цель включена. 0 - выключена и не дает опыта',
  `total_exp_given` int(11) NOT NULL DEFAULT '0' COMMENT 'Сколько опыта игроки получили за все время',
  `comment` varchar(512) DEFAULT NULL COMMENT 'Комментарий к источнику опыта (не показывается)',
  PRIMARY KEY (`alias`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Типы целей, которые должен выполнять игрок, чтобы получать опыт.\r\nЦели можно отключать, это не приведет к ошибкам, но статистика цели не будет вестись';

-- Dumping data for table mtaw.objective_type: ~5 rows (приблизно)
/*!40000 ALTER TABLE `objective_type` DISABLE KEYS */;
INSERT INTO `objective_type` (`alias`, `title`, `description`, `amount`, `experience`, `enabled`, `total_exp_given`, `comment`) VALUES
	('consumeFood', 'Потребление пищи', 'Ешьте все подряд', 64, 1, 1, 1, NULL),
	('disruptFruits', 'Сбор фруктов', 'Срывайте ягоды с фруктовых деревьев', 64, 2, 1, 4, NULL),
	('disruptHerbs', 'Сбор урожая', 'Срывайте растения (например, на ферме)', 64, 1, 1, 17, NULL),
	('playOneHour', 'Время жизни', 'Проведите в игре один игровой час', 60, 5, 1, 4505, '+5xp / игровой час (15 минут)');
/*!40000 ALTER TABLE `objective_type` ENABLE KEYS */;


-- Dumping structure for таблиця mtaw.permission
CREATE TABLE IF NOT EXISTS `permission` (
  `alias` varchar(32) NOT NULL,
  `title` varchar(256) NOT NULL,
  PRIMARY KEY (`alias`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Права, которые есть на сервере';

-- Dumping data for table mtaw.permission: ~0 rows (приблизно)
/*!40000 ALTER TABLE `permission` DISABLE KEYS */;
INSERT INTO `permission` (`alias`, `title`) VALUES
	('attachments', 'Редактирование прикрепленных объектов'),
	('damage', 'Нанесение урона игрокам'),
	('developer', 'Разработчик'),
	('giveItem', 'Создание вещей'),
	('vehicleHandling', 'Редактирование параметров handling транспорта'),
	('vehicleSpawn', 'Создание транспорта');
/*!40000 ALTER TABLE `permission` ENABLE KEYS */;


-- Dumping structure for таблиця mtaw.session
CREATE TABLE IF NOT EXISTS `session` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `login` varchar(33) NOT NULL,
  `account` int(11) NOT NULL,
  `ip` char(15) NOT NULL,
  `serial` char(32) NOT NULL,
  `date` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ip_serial` (`ip`,`serial`)
) ENGINE=InnoDB AUTO_INCREMENT=5445 DEFAULT CHARSET=utf8 COMMENT='Сессии входа';


-- Dumping structure for таблиця mtaw.spawn
CREATE TABLE IF NOT EXISTS `spawn` (
  `alias` varchar(128) NOT NULL,
  `name` varchar(128) NOT NULL COMMENT 'Название локации',
  `area_minx` float NOT NULL COMMENT 'Min X зоны действия',
  `area_maxx` float NOT NULL COMMENT 'Max X зоны действия',
  `area_miny` float NOT NULL COMMENT 'Min Y зоны действия',
  `area_maxy` float NOT NULL COMMENT 'Max Y зоны действия',
  `x` float NOT NULL COMMENT 'Точка респавна',
  `y` float NOT NULL,
  `z` float NOT NULL,
  `weight` float NOT NULL COMMENT 'Вес / качество (при выборе точки, куда идти боту)',
  `comfort` float NOT NULL COMMENT 'Макс. уровень уюта (проценты, минимум 0)',
  `cleanliness` float NOT NULL COMMENT 'Чистота',
  `charging` float NOT NULL COMMENT 'Восстановление энергии (единиц в игровой час)',
  `opened` int(11) NOT NULL DEFAULT '0' COMMENT 'Спавн по умолчанию открыт всем',
  PRIMARY KEY (`alias`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Локации и точки респавна игроков';

-- Dumping data for table mtaw.spawn: ~1 rows (приблизно)
/*!40000 ALTER TABLE `spawn` DISABLE KEYS */;
INSERT INTO `spawn` (`alias`, `name`, `area_minx`, `area_maxx`, `area_miny`, `area_maxy`, `x`, `y`, `z`, `weight`, `comfort`, `cleanliness`, `charging`, `opened`) VALUES
	('homeless', 'Пристань бездомных', 188, 227, -278, -219, 208, -260, 5, 1, 3, -1, 3, 1);
/*!40000 ALTER TABLE `spawn` ENABLE KEYS */;


-- Dumping structure for таблиця mtaw.vinyl
CREATE TABLE IF NOT EXISTS `vinyl` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `category` int(11) DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `width` int(11) NOT NULL,
  `height` int(11) NOT NULL,
  `colorable` int(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `FK_vinyl_vinyl_category` (`category`),
  CONSTRAINT `FK_vinyl_vinyl_category` FOREIGN KEY (`category`) REFERENCES `vinyl_category` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8 COMMENT='Винилы для машин';

-- Dumping data for table mtaw.vinyl: ~5 rows (приблизно)
/*!40000 ALTER TABLE `vinyl` DISABLE KEYS */;
INSERT INTO `vinyl` (`id`, `category`, `name`, `width`, `height`, `colorable`) VALUES
	(1, 3, 'Бабочка и ноты', 907, 272, 1),
	(2, 2, 'Длинный огонь от колеса', 530, 151, 1),
	(3, 1, 'Деколь NOS', 512, 256, 1),
	(4, 1, 'Деколь Alpine', 512, 256, 1),
	(5, 1, 'Деколь Sparco', 512, 256, 1),
	(6, 1, 'Деколь Formula Drift', 512, 256, 1);
/*!40000 ALTER TABLE `vinyl` ENABLE KEYS */;


-- Dumping structure for таблиця mtaw.vinyl_category
CREATE TABLE IF NOT EXISTS `vinyl_category` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;

-- Dumping data for table mtaw.vinyl_category: ~2 rows (приблизно)
/*!40000 ALTER TABLE `vinyl_category` DISABLE KEYS */;
INSERT INTO `vinyl_category` (`id`, `name`) VALUES
	(1, 'Деколи'),
	(2, 'Огонь'),
	(3, 'Музыка');
/*!40000 ALTER TABLE `vinyl_category` ENABLE KEYS */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

DELIMITER //
CREATE PROCEDURE `AddPlayerTime`(IN `_Map` VARCHAR(255), IN `_Type` INT, IN `_Style` INT, IN `_PlayerID` INT, IN `_Time` FLOAT, IN `_Jumps` INT, IN `_Strafes` INT, IN `_Timestamp` INT, IN `_Sync` FLOAT, IN `_tas` INT, IN `_IsRecord` TINYINT)
BEGIN
	SET @_MapID:=(SELECT MapID FROM maps WHERE MapName = _Map);
	DELETE FROM times WHERE MapID=@_MapID AND Type=_Type AND Style=_Style AND PlayerID=_PlayerID AND tas=_tas;
    
    INSERT INTO times (MapID, Type, Style, PlayerID, Time, Jumps, Strafes, Timestamp, Sync, tas) VALUES (@_MapID, _Type, _Style, _PlayerID, _Time, _Jumps, _Strafes, _Timestamp, _Sync, _tas);
    SET @_TimeInsertID:=LAST_INSERT_ID();
	
    IF(_IsRecord = 1)
    THEN
    	SET @TotalRecords := (SELECT count(*) from recent_records WHERE MapID=@_MapID AND Type=_Type AND Style=_Style AND TAS=_tas);
        IF(@TotalRecords > 0)
        THEN
        	SET @CurrentRecordHolder := (SELECT PlayerID FROM recent_records WHERE MapID=@_MapID AND Type=_Type AND Style=_Style AND TAS=_tas AND IsRecord = 1 LIMIT 0, 1);
            if(_PlayerID != @CurrentRecordHolder)
            THEN
            	SET @OeeTimeId := (SELECT id FROM recent_records WHERE MapID=@_MapID AND Type=_Type AND Style=_Style AND TAS=_tas AND IsRecord = 1 LIMIT 0, 1);
            	INSERT INTO overtake (Overtaker, OvertakerTimeId, Overtakee, OvertakeeTimeId, Timestamp) VALUES (_PlayerID, @_TimeInsertID, @CurrentRecordHolder, @OeeTimeId, UNIX_TIMESTAMP());
            END IF;
        END IF;
        
		INSERT INTO recent_records (MapID, Type, Style, PlayerID, Time, Jumps, Strafes, Timestamp, Sync, TAS, IsRecord, StillExists, id) VALUES ((SELECT MapID FROM maps WHERE MapName=_Map LIMIT 0, 1), _Type, _Style, _PlayerID, _Time, _Jumps, _Strafes, _Timestamp, _Sync, _tas, 		1, 1, @_TimeInsertID);
		UPDATE recent_records SET IsRecord = 0 WHERE MapID = @_MapID AND Type = _Type AND Style = _Style AND TAS = _tas AND id != @_TimeInsertID;
		UPDATE recent_records SET StillExists = 0 WHERE MapID = @_MapID AND Type = _Type AND Style = _Style AND TAS = _tas AND id NOT IN (SELECT rownum FROM times WHERE MapID = @_MapID AND Type = _Type AND Style = _Style AND tas = _tas);
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `DeleteTimes`(IN _Map VARCHAR(255), IN _Type INT, IN _Style INT, IN _tas INT, IN _MinPos INT, IN _MaxPos INT)
BEGIN
	SET @_MapID:=(SELECT MapID FROM maps WHERE MapName = _Map);
    SET @_Offset:=_MaxPos - _MinPos + 1;
    SET @MinPos:=_MinPos;
    SET @__Type:=_Type;
    SET @__Style:=_Style;
    Set @__tas:=_tas;
    
    PREPARE stmt FROM "DELETE FROM times WHERE rownum IN (SELECT b.rownum FROM 
	(SELECT * FROM times WHERE MapID=? AND Type=? AND Style=? AND tas=? ORDER BY time ASC) a 
	JOIN 
	(SELECT * FROM times WHERE MapID=? AND Type=? AND Style=? AND tas=? ORDER BY time ASC LIMIT ?, ?) b 
	ON a.rownum=b.rownum);";
    EXECUTE stmt USING @_MapID, @__Type, @__Style, @__tas, @_MapID, @__Type, @__Style, @__tas, @MinPos, @_Offset;
	
	IF(_MinPos = 0)
	THEN
		UPDATE recent_records SET IsRecord = 0 WHERE MapID = @_MapID AND Type = _Type AND Style = _Style AND TAS = _tas AND IsRecord = 1;
		UPDATE recent_records SET StillExists = 0 WHERE Type = _Type AND Style = _Style AND TAS = _tas AND id NOT IN (SELECT rownum FROM times WHERE MapID = @_MapID AND Type = _Type AND Style = _Style AND TAS = _tas);
	END IF;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS `maps` (
  `MapID` int(11) NOT NULL AUTO_INCREMENT,
  `MapName` text,
  `Tier` int(11) DEFAULT '3',
  `InMapCycle` tinyint(4) NOT NULL DEFAULT '0',
  `HasZones` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`MapID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `overtake` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `Overtaker` int(11) DEFAULT NULL,
  `OvertakerTimeId` int(11) DEFAULT NULL,
  `Overtakee` int(11) DEFAULT NULL,
  `OvertakeeTimeId` int(11) DEFAULT NULL,
  `Timestamp` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `players` (
  `PlayerID` int(11) NOT NULL AUTO_INCREMENT,
  `SteamID` varchar(50) DEFAULT NULL,
  `User` varchar(50) DEFAULT NULL,
  `Playtime` int(11) NOT NULL DEFAULT '0',
  `LastConnection` int(11) DEFAULT '0',
  PRIMARY KEY (`PlayerID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `ranks_maps` (
  `MapID` int(11) DEFAULT NULL,
  `PlayerID` int(11) DEFAULT NULL,
  `Type` int(11) DEFAULT NULL,
  `Style` int(11) DEFAULT NULL,
  `Points` float DEFAULT NULL,
  `Rank` int(11) DEFAULT NULL,
  `rowkey` int(11) NOT NULL AUTO_INCREMENT,
  `tas` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`rowkey`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `ranks_overall` (
  `PlayerID` int(11) DEFAULT NULL,
  `Points` float DEFAULT NULL,
  `Rank` int(11) DEFAULT NULL,
  `rowkey` bigint(20) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`rowkey`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `ranks_styles` (
  `PlayerID` int(11) DEFAULT NULL,
  `Type` int(11) DEFAULT NULL,
  `Style` int(11) DEFAULT NULL,
  `Points` float DEFAULT NULL,
  `Rank` int(11) DEFAULT NULL,
  `rowkey` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`rowkey`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

DELIMITER //
CREATE PROCEDURE `recalcmappts`(IN `map` VARCHAR(255), IN `inType` int, IN `inStyle` int, IN `inTAS` int)
BEGIN
	SET @vmapid:=(SELECT MapID FROM maps WHERE MapName = map LIMIT 0, 1);

	SET @MapTier:=(SELECT Tier FROM maps WHERE MapID=@vmapid);
	IF(inType = 1)
	THEN
		SET @MapTier:=1;
	END IF;
	SET @Competition:=(SELECT count(*) FROM times WHERE MapID=@vmapid AND Type=inType AND Style=inStyle AND tas=inTAS);
	SET @curRank:=0;
	
	SET @pointScale:=1;
    
	IF(inTAS = 1)
	THEN
		SET @pointScale:=0;
	END IF;
	
	DELETE FROM ranks_maps WHERE MapID=@vmapid AND Type=inType AND Style=inStyle AND tas=inTAS;
	INSERT INTO ranks_maps (MapID, PlayerID, Type, Style, tas, Points, Rank)
	SELECT @vmapid, PlayerID, inType, inStyle, inTAS, @MapTier * (@Competition - @curRank) * @pointScale AS Points, CASE
	WHEN @curRank := @curRank + 1 THEN @curRank
	END AS Rank
	FROM times
	WHERE MapID=@vmapid AND Type=inType AND Style=inStyle AND tas=inTAS
	ORDER BY Time, Timestamp;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `recalcpts`(IN inMainStyleList int, IN inBonusStyleList int)
BEGIN
	DELETE FROM ranks_overall;

	SET @curRank:=0;

	INSERT INTO ranks_overall (PlayerID, Points, Rank)
	SELECT PlayerID, t.Points AS Points,
	CASE WHEN @curRank := @curRank + 1 THEN @curRank
	END AS Rank
	FROM (SELECT PlayerID, SUM(Points) AS Points FROM ranks_styles WHERE 
          CASE 
          WHEN Type = 0 THEN inMainStyleList & (1 << Style) > 0 
          WHEN Type = 1 THEN inBonusStyleList & (1 << Style) > 0
		  END
          GROUP BY PlayerID ORDER BY SUM(Points) DESC) t;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `recalcstylepts`(IN inType int, IN inStyle int)
BEGIN
		DELETE FROM ranks_styles WHERE Type=inType AND Style=inStyle;

		SET @curRank:=0;
		
		SET @zones:=3;
		IF(inType = 1)
		THEN
			SET @zones:=12;
		END IF;

		INSERT INTO ranks_styles (PlayerID, Type, Style, Points, Rank)
		SELECT PlayerID, inType, inStyle, t.Points AS Points,
		CASE WHEN @curRank := @curRank + 1 THEN @curRank
		END AS Rank
		FROM (SELECT rm.PlayerID, rm.Type, rm.Style, SUM(rm.Points) AS Points FROM ranks_maps AS rm, maps AS m WHERE Type=inType AND Style=inStyle AND rm.MapID=m.MapID AND m.InMapCycle=1 AND m.HasZones & @zones = @zones GROUP BY PlayerID ORDER BY SUM(Points) DESC) t;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS `recent_records` (
  `MapID` int(11) DEFAULT NULL,
  `PlayerID` int(11) DEFAULT NULL,
  `Type` int(11) DEFAULT NULL,
  `Style` int(11) DEFAULT NULL,
  `TAS` int(11) DEFAULT NULL,
  `Time` float DEFAULT NULL,
  `Jumps` int(11) DEFAULT NULL,
  `Strafes` int(11) DEFAULT NULL,
  `Timestamp` int(11) DEFAULT NULL,
  `Sync` float DEFAULT NULL,
  `id` int(11) NOT NULL,
  `StillExists` tinyint(4) DEFAULT '0',
  `IsRecord` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `times` (
  `rownum` int(11) NOT NULL AUTO_INCREMENT,
  `MapID` int(11) DEFAULT NULL,
  `Type` int(11) DEFAULT NULL,
  `Style` int(11) DEFAULT NULL,
  `PlayerID` int(11) DEFAULT NULL,
  `Time` double DEFAULT NULL,
  `Jumps` int(11) DEFAULT NULL,
  `Strafes` int(11) DEFAULT NULL,
  `Timestamp` int(11) DEFAULT NULL,
  `Sync` double DEFAULT NULL,
  `tas` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`rownum`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `zones` (
  `RowID` int(11) NOT NULL AUTO_INCREMENT,
  `MapID` int(11) DEFAULT NULL,
  `Type` int(11) DEFAULT NULL,
  `point00` double DEFAULT NULL,
  `point01` double DEFAULT NULL,
  `point02` double DEFAULT NULL,
  `point10` double DEFAULT NULL,
  `point11` double DEFAULT NULL,
  `point12` double DEFAULT NULL,
  `unrestrict` int(11) NOT NULL DEFAULT '0',
  `ezhop` int(11) NOT NULL DEFAULT '0',
  `autohop` int(11) NOT NULL DEFAULT '0',
  `nolimit` int(11) NOT NULL DEFAULT '0',
  `actype` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`RowID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;

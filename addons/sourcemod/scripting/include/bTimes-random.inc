#define STOP_DOORS   	1<<0
#define STOP_GUNS    	1<<1
#define STOP_MUSIC   	1<<2
#define AUTO_BHOP    	1<<3
#define HIDE_PLAYERS 	1<<4
#define KH_TIMELEFT	1<<5
#define SHOW_KEYS    	1<<6
#define SHOW_HINT    	1<<7
#define SHOW_2DVEL   	1<<8
#define STOP_RECSND	1<<9
#define KH_SYNC		1<<10
#define KH_RECORD		1<<11
#define KH_BEST		1<<12
#define KH_SPECS		1<<13
#define STOP_PBSND     1<<14
#define STOP_FAILSND   1<<15

native GetClientSettings(client);
native SetClientSettings(client, settings);
forward OnTimerChatChanged(MessageType, String:Message[]);
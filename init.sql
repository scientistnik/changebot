create table if not exists users (
	uid integer primary key not null,
	username varchar(30) not null,
	tid int not null,
	status character(20),
	karma int not null default 0
);

create table if not exists balances (
	bid integer primary key not null,
	uid integer not null,
	asid integer not null,
	dtime datetime default current_timestamp
);

create table if not exists assets (
	asid integer primary key not null,
	name character(20)
);

insert into assets(name) select 'bitRUB' where not exists(select 1 from assets where name='bitRUB');
insert into assets(name) select 'bitUSD' where not exists(select 1 from assets where name='bitUSD');
insert into assets(name) select 'bitEUR' where not exists(select 1 from assets where name='bitEUR');
insert into assets(name) select 'bitBTC' where not exists(select 1 from assets where name='bitBTC');

insert into assets(name) select 'Сбербанк' where not exists(select 1 from assets where name='Сбербанк');
insert into assets(name) select 'Тинькофф' where not exists(select 1 from assets where name='Тинькофф');
insert into assets(name) select 'Альфа' where not exists(select 1 from assets where name='Альфа');
insert into assets(name) select 'Райффайзен' where not exists(select 1 from assets where name='Райффайзен');
insert into assets(name) select 'Payeer' where not exists(select 1 from assets where name='Payeer');
insert into assets(name) select 'Qiwi' where not exists(select 1 from assets where name='Qiwi');

create table if not exists announces (
	anid integer primary key,
	uid integer not null,
	giveas integer not null,
	getas integer not null, 
	antext text,
	foreign key (uid) references users(uid),
	foreign key (giveas) references assets(asid),
	foreign key (getas) references assets(asid)
);

create table if not exists blacklist (
	bid integer primary key not null,
	tid int not null
);

create table if not exists likes (
	lid integer primary key not null,
	uid_do integer not null,
	uid_get integer not null,
	action int2,
	foreign key (uid_do) references users(uid),
	foreign key (uid_get) references users(uid)
);

CREATE TABLE ban (
	id varchar(127) NOT NULL,
	name varchar(255) NOT NULL,
	reason varchar(255) NOT NULL,
	expires datetime,
	PRIMARY KEY (id)
)

CREATE TABLE role_boitier (id serial PRIMARY KEY, designation text);

CREATE TABLE situation (id serial PRIMARY KEY, designation text);

CREATE TABLE type_ptech (id serial PRIMARY KEY, designation text);

CREATE TABLE capacite (id serial PRIMARY KEY, capacite integer);

CREATE TABLE proprietaire (id serial PRIMARY KEY, designation text);

CREATE TABLE ptech (id serial PRIMARY KEY, identifiant text, id_type_ptech integer, id_proprietaire integer, geom geometry(POINT, 2154),
	CONSTRAINT ptech_type FOREIGN KEY (id_type_ptech) REFERENCES type_ptech (id),
	CONSTRAINT proprietaire FOREIGN KEY (id_proprietaire) REFERENCES proprietaire (id));

CREATE TABLE conduite (id serial PRIMARY KEY, identifiant text, id_situation integer, id_proprietaire integer, geom geometry(LINESTRING, 2154),
	CONSTRAINT conduite_situation FOREIGN KEY (id_situation) REFERENCES situation (id));

INSERT INTO role_boitier (designation) VALUES ('PM');
INSERT INTO role_boitier (designation) VALUES ('BPE');
INSERT INTO role_boitier (designation) VALUES ('PBO');

INSERT INTO situation (designation) VALUES ('Aerien');
INSERT INTO situation (designation) VALUES ('Souterrain');
INSERT INTO situation (designation) VALUES ('Aerosouterrain');

INSERT INTO type_ptech (designation) VALUES ('Chambre');
INSERT INTO type_ptech (designation) VALUES ('Poteau');
INSERT INTO type_ptech (designation) VALUES ('Facade');

INSERT INTO capacite (capacite) VALUES (12);
INSERT INTO capacite (capacite) VALUES (24);
INSERT INTO capacite (capacite) VALUES (36);
INSERT INTO capacite (capacite) VALUES (48);
INSERT INTO capacite (capacite) VALUES (72);
INSERT INTO capacite (capacite) VALUES (96);
INSERT INTO capacite (capacite) VALUES (144);
INSERT INTO capacite (capacite) VALUES (288);
INSERT INTO capacite (capacite) VALUES (432);
INSERT INTO capacite (capacite) VALUES (576);
INSERT INTO capacite (capacite) VALUES (720);

INSERT INTO proprietaire (designation) VALUES ('Orange');
INSERT INTO proprietaire (designation) VALUES ('Enedis');
INSERT INTO proprietaire (designation) VALUES ('Commune');
INSERT INTO proprietaire (designation) VALUES ('Collectivité');
INSERT INTO proprietaire (designation) VALUES ('Autre');
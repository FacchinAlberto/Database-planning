show DATABASES;

use ts_trasporti;

show tables;

select * from account;
select * from ufficio;
select * from dipendente;
select * from autista;
select * from passeggero;
select * from linea;
select * from fermata;
select * from tratta;
select * from composizione;
select *  from mezzo;
select * from viaggio;
select * from prenotazione;

select nome, cognome 
from autista
inner join account
on utente = IdAutista;

# Selezionare i posti rimanenti per i mezzi di una determinata linea in una certa fascia oraria
drop procedure posti_rimanenti;
DELIMITER $$
create procedure posti_rimanenti(IN linea_input varchar(3), 
IN partenza_input CHAR(5), IN arrivo_input CHAR(5))
BEGIN
	select l.denominazione as linea, m.postiDisponibili as posti, v.data,
    v.oraPartenza as partenza, v.oraArrivo as arrivo
	from Viaggio v
	inner join Linea l
	on v.linea = l.idLinea
	inner join Tratta t
	on v.tratta = t.idTratta
	inner join Mezzo m
	on l.idLinea = m.linea
    where l.denominazione = linea_input 
    and v.oraPartenza >= partenza_input and v.oraArrivo <= arrivo_input 
    and m.postiDisponibili <> 0;
END $$
DELIMITER ;

set @linea_input = "17/";
set @partenza_input = "00:00";
set @arrivo_input = "23:59";
call posti_rimanenti(@linea_input, @partenza_input, @arrivo_input);


# trigger per controllare che, prenotando una determinata quantità di posti, 
# il numero di posti rimanenti non diventi <0
drop trigger trg_zero;
DELIMITER $$
CREATE TRIGGER trg_zero
BEFORE INSERT ON prenotazione
FOR EACH ROW
BEGIN
	DECLARE num_posti INT;
	select sum(postiDisponibili) into num_posti
    from Mezzo m 
    inner join Linea l
    on m.linea = l.idLinea
    inner join Viaggio v
    on v.linea = l.idLinea
    inner join Prenotazione p
    on p.viaggio = v.idViaggio
    where NEW.viaggio = v.idViaggio;
	
	if (num_posti - NEW.quantità) < 0 THEN
		signal sqlstate "02000"
        set message_text = "Numero posti rimasti insufficiente";
	end if;
END $$
DELIMITER ;

insert into prenotazione(dataPrenotazione, quantità, viaggio, passeggero) values (curdate(), 50, 1, 1);

# trigger per aggiornare il numero di posti rimanenti in un mezzo 
# dopo una prenotazione effettuata da un passeggero
drop trigger trg_posti;
DELIMITER $$
CREATE TRIGGER trg_posti
AFTER INSERT ON prenotazione
FOR EACH ROW
BEGIN
	update mezzo as m
    inner join (select idMezzo 
    from Mezzo m 
    inner join Linea l 
    on m.linea = l.idLinea 
    inner join Viaggio v 
    on v.linea = l.idLinea 
    inner join Prenotazione p 
    on p.viaggio = v.idViaggio 
    where NEW.viaggio = v.idViaggio) as tmp on m.idMezzo = tmp.idMezzo
    set postiDisponibili = postiDisponibili - NEW.quantità;
END $$
DELIMITER ;

select * from prenotazione;
select * from viaggio;
select * from linea;
select * from mezzo;
delete from prenotazione where idPrenotazione > 3;

# visualizzare informazioni di recup di una determinata prenotazione
# usd per calcolare il costo totale
drop function costo_totale;
DELIMITER $$
create function costo_totale(prenotazione_input INT, quantita_input INT)
returns float (5, 2)
deterministic
BEGIN
	declare costo_tot float (5, 2);
	select (quantita_input * t.costo) into costo_tot
    from Tratta t
    inner join Viaggio v
    on t.idTratta = v.tratta
    inner join Prenotazione p
    on p.viaggio = v.idViaggio
    where p.idPrenotazione = prenotazione_input;
    return costo_tot;
END $$
DELIMITER ;

set @prenotazione_input = 3;

select p.idPrenotazione as codice, v.data, v.oraPartenza as partenza,
v.oraArrivo as arrivo, p.quantità, concat(costo_totale(@tratta_input, p.quantità), "€") as totale
from Prenotazione p
inner join Viaggio v
on p.viaggio = v.idViaggio
inner join Tratta t
on t.idTratta = v.tratta
where p.idPrenotazione = @prenotazione_input;


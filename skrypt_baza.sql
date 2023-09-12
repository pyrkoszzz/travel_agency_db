-- Patryk Pyrkosz INF gr.2 119254
DROP DATABASE IF EXISTS projekt_baza_danych;
CREATE DATABASE projekt_baza_danych;
USE projekt_baza_danych;

-- Tworzenie tabeli "Klienci"
CREATE TABLE Klienci (
  ID_klienta INT PRIMARY KEY,
  Imię VARCHAR(50),
  Nazwisko VARCHAR(50),
  Adres VARCHAR(100),
  Numer_telefonu VARCHAR(20),
  Adres_email VARCHAR(100)
);

-- Tworzenie tabeli "Wycieczki"
CREATE TABLE Wycieczki (
  ID_wycieczki INT PRIMARY KEY,
  Nazwa VARCHAR(100),
  Opis TEXT,
  Data_rozpoczęcia DATE,
  Data_zakończenia DATE,
  Cena DECIMAL(10, 2),
  Miejsca DECIMAL(10,1)
);

-- Tworzenie tabeli "Hotele"
CREATE TABLE Hotele (
  ID_hotelu INT PRIMARY KEY,
  Nazwa VARCHAR(100),
  Adres VARCHAR(100),
  Miasto VARCHAR(50),
  Kraj VARCHAR(50),
  Ocena DECIMAL(2, 1),
  Cena_za_noc DECIMAL(10, 2)
);

-- Tworzenie tabeli "Przewoźnicy"
CREATE TABLE Przewoźnicy (
  ID_przewoźnika INT PRIMARY KEY,
  Nazwa VARCHAR(100),
  Adres VARCHAR(100),
  Miasto VARCHAR(50),
  Kraj VARCHAR(50),
  Ocena DECIMAL(2, 1)
);

-- Tworzenie tabeli "Rezerwacje"
CREATE TABLE Rezerwacje (
  ID_rezerwacji INT PRIMARY KEY,
  ID_klienta INT,
  ID_wycieczki INT,
  ID_hotelu INT,
  ID_przewoźnika INT,
  Data_rezerwacji DATE,
  Ilość_osób INT,
  Cena DECIMAL(10, 2),
  FOREIGN KEY (ID_klienta) REFERENCES Klienci(ID_klienta),
  FOREIGN KEY (ID_wycieczki) REFERENCES Wycieczki(ID_wycieczki),
  FOREIGN KEY (ID_hotelu) REFERENCES Hotele(ID_hotelu),
  FOREIGN KEY (ID_przewoźnika) REFERENCES Przewoźnicy(ID_przewoźnika)
);

-- Tworzenie tabeli "Logi"
CREATE TABLE Logi (
  ID_logu INT PRIMARY KEY AUTO_INCREMENT,
  Data TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  Akcja VARCHAR(30),
  Opis VARCHAR(60)
);

-- Dodawanie indeksu do tabeli "Przewoźnicy" na kolumnie "Kraj"
CREATE INDEX idx_przewoznicy_kraj ON Przewoźnicy (Kraj);

-- Dodawanie indeksu do tabeli "Klienci" na kolumnie "Nazwisko"
CREATE INDEX idx_klienci_nazwisko ON Klienci (Nazwisko);

-- Dodawanie indeksu do tabeli "Wycieczki" na kolumnach "Data_rozpoczęcia" i "Data_zakończenia"
CREATE INDEX idx_wycieczki_data ON Wycieczki (Data_rozpoczęcia, Data_zakończenia);

-- Dodawanie indeksu do tabeli "Rezerwacje" na kolumnie "Data_rezerwacji"
CREATE INDEX idx_rezerwacje_data ON Rezerwacje (Data_rezerwacji);

-- Procedura umożliwia dodanie nowego klienta do bazy danych biura podróży.
DELIMITER //
CREATE PROCEDURE DodajKlienta(
  IN imie VARCHAR(50),
  IN nazwisko VARCHAR(50),
  IN adres VARCHAR(100),
  IN numer_telefonu VARCHAR(20),
  IN adres_email VARCHAR(100)
)
BEGIN
  INSERT INTO Klienci (Imię, Nazwisko, Adres, Numer_telefonu, Adres_email)
  VALUES (imie, nazwisko, adres, numer_telefonu, adres_email);
END //
DELIMITER ;

-- Procedura umożliwia wyszukiwanie wycieczek, które odbywają się w określonym przedziale dat.
DELIMITER //
CREATE PROCEDURE ZnajdzWycieczki(
  IN data_poczatkowa DATE,
  IN data_koncowa DATE
)
BEGIN
  SELECT *
  FROM Wycieczki
  WHERE Data_rozpoczęcia >= data_poczatkowa AND Data_zakończenia <= data_koncowa;
END //
DELIMITER ;

-- Procedura zwraca wszystkie rezerwacje danego klienta wraz z powiązanymi informacjami o wycieczce, hotelu i przewoźniku.
DELIMITER //
CREATE PROCEDURE PobierzRezerwacjeKlienta(
  IN id_klienta INT
)
BEGIN
  SELECT r.*, w.Nazwa, h.Nazwa AS Nazwa_hotelu, p.Nazwa AS Nazwa_przewoznika
  FROM Rezerwacje r
  JOIN Wycieczki w ON r.ID_wycieczki = w.ID_wycieczki
  JOIN Hotele h ON r.ID_hotelu = h.ID_hotelu
  JOIN Przewoźnicy p ON r.ID_przewoźnika = p.ID_przewoźnika
  WHERE r.ID_klienta = id_klienta;
END //
DELIMITER ;

-- Procedura pozwala na dokonanie rezerwacji wycieczki dla określonego klienta.
DELIMITER //
CREATE PROCEDURE RezerwujWycieczke(
  IN klient_id INT,
  IN wycieczka_id INT,
  IN id_hotelu INT,
  IN id_przewoznika INT,
  IN data_rezerwacji DATE,
  IN ilosc_osob INT
)
BEGIN
  DECLARE dostepne_miejsca INT;
  DECLARE cena_wycieczki DECIMAL(10, 2);
  DECLARE rabat DECIMAL(10, 2);
  DECLARE cena_po_rabacie DECIMAL(10, 2);

  -- Sprawdzenie dostępności miejsc
  SELECT Miejsca INTO dostepne_miejsca
  FROM Wycieczki
  LEFT JOIN Rezerwacje USING (ID_wycieczki)
  WHERE ID_wycieczki = wycieczka_id
  GROUP BY ID_wycieczki;

  IF dostepne_miejsca IS NULL OR dostepne_miejsca < ilosc_osob THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Brak wystarczającej liczby miejsc.';
  ELSE
    -- Pobranie ceny wycieczki
    SELECT Cena INTO cena_wycieczki
    FROM Wycieczki
    WHERE ID_wycieczki = wycieczka_id;

    -- Obliczenie rabatu (jeśli dotyczy)
    IF ilosc_osob > 5 THEN
      SET rabat = 0.1;
    ELSE
      SET rabat = 0;
    END IF;

    -- Obliczenie ceny po rabacie
    SET cena_po_rabacie = cena_wycieczki * (1 - rabat);

    -- Wstawienie rekordu rezerwacji
    INSERT INTO Rezerwacje (ID_klienta, ID_wycieczki, ID_hotelu, ID_przewoźnika, Data_rezerwacji, Ilość_osób, Cena)
    VALUES (klient_id, wycieczka_id, id_hotelu, id_przewoźnika, data_rezerwacji, ilosc_osob, cena_po_rabacie);
  END IF;
END //
DELIMITER ;

-- Wyzwalacz przechwytuje zdarzenia dodawania nowych rezerwacji i zapisuje je w tabeli "LogiSystemowe" wraz z datą, akcją i opisem.
DELIMITER //
CREATE TRIGGER LogSystemowy AFTER INSERT ON Rezerwacje
FOR EACH ROW
BEGIN
  INSERT INTO Logi (Data, Akcja, Opis)
  VALUES (CURRENT_TIMESTAMP, 'Dodanie rezerwacji', CONCAT('Dodano rezerwację o ID: ', NEW.ID_rezerwacji));
END //
DELIMITER ;

-- Wyzwalacz sprawdza poprawność formatu numeru telefonu podczas dodawania nowego klienta. Jeśli numer telefonu nie jest liczbą, wyzwalacz zgłasza błąd.
DELIMITER //
CREATE TRIGGER WalidacjaKlienta BEFORE INSERT ON Klienci
FOR EACH ROW
BEGIN
  IF NEW.Numer_telefonu NOT REGEXP '^[0-9]+$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Błędny format numeru telefonu';
  END IF;
END //
DELIMITER ;

-- Wyzwalacz sprawdza, czy cena wycieczki jest większa od zera podczas dodawania nowej wycieczki. Jeśli cena jest równa lub mniejsza od zera, wyzwalacz zgłasza błąd.
DELIMITER //
CREATE TRIGGER WalidacjaWycieczki BEFORE INSERT ON Wycieczki
FOR EACH ROW
BEGIN
  IF NEW.Cena <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cena wycieczki musi być większa od zera';
  END IF;
END //
DELIMITER ;

-- Wyzwalacz przechwytuje zdarzenia usuwania przewoźników i zapisuje je w tabeli "LogiSystemowe" wraz z datą, akcją i opisem.
DELIMITER //
CREATE TRIGGER LogSystemowyPrzewoznik AFTER DELETE ON Przewoźnicy
FOR EACH ROW
BEGIN
  INSERT INTO Logi (Data, Akcja, Opis)
  VALUES (CURRENT_TIMESTAMP, 'Usunięcie przewoźnika', CONCAT('Usunięto przewoźnika o ID: ', OLD.ID_przewoźnika));
END //
DELIMITER ;

-- Wypełnienie tabeli "Klienci" danymi
INSERT INTO Klienci (ID_klienta, Imię, Nazwisko, Adres, Numer_telefonu, Adres_email)
VALUES
  (1, 'Jan', 'Kowalski', 'ul. Główna 1, Warszawa', '123456789', 'jan.kowalski@example.com'),
  (2, 'Anna', 'Nowak', 'ul. Kwiatowa 5, Kraków', '987654321', 'anna.nowak@example.com'),
  (3, 'Piotr', 'Wiśniewski', 'ul. Słoneczna 3, Gdynia', '555111222', 'piotr.wisniewski@example.com'),
  (4, 'Maria', 'Kaczmarek', 'ul. Długa 7, Wrocław', '777888999', 'maria.kaczmarek@example.com'),
  (5, 'Andrzej', 'Zając', 'ul. Cicha 2, Poznań', '111222333', 'andrzej.zajac@example.com'),
  (6, 'Katarzyna', 'Król', 'ul. Polna 9, Łódź', '444555666', 'katarzyna.krol@example.com'),
  (7, 'Michał', 'Wróbel', 'ul. Zielona 4, Szczecin', '999000111', 'michal.wrobel@example.com'),
  (8, 'Magdalena', 'Krawczyk', 'ul. Wiosenna 8, Lublin', '222333444', 'magdalena.krawczyk@example.com'),
  (9, 'Tadeusz', 'Dąbrowski', 'ul. Leśna 6, Białystok', '666777888', 'tadeusz.dabrowski@example.com'),
  (10, 'Alicja', 'Woźniak', 'ul. Ogrodowa 11, Katowice', '111222333', 'alicja.wozniak@example.com'),
  (11, 'Robert', 'Jankowski', 'ul. Morska 10, Gdańsk', '444555666', 'robert.jankowski@example.com'),
  (12, 'Weronika', 'Michalska', 'ul. Dąbrowskiego 2, Kraków', '777888999', 'weronika.michalska@example.com'),
  (13, 'Krzysztof', 'Lis', 'ul. Słowackiego 5, Warszawa', '222333444', 'krzysztof.lis@example.com'),
  (14, 'Patrycja', 'Piotrowska', 'ul. Mickiewicza 8, Wrocław', '999000111', 'patrycja.piotrowska@example.com'),
  (15, 'Szymon', 'Kubiak', 'ul. Jasna 3, Poznań', '111222333', 'szymon.kubiak@example.com'),
  (16, 'Monika', 'Cieślak', 'ul. Słoneczna 9, Gdynia', '555111222', 'monika.cieslak@example.com'),
  (17, 'Grzegorz', 'Witkowski', 'ul. Cicha 7, Łódź', '777888999', 'grzegorz.witkowski@example.com'),
  (18, 'Oliwia', 'Sikora', 'ul. Wiosenna 5, Szczecin', '222333444', 'oliwia.sikora@example.com'),
  (19, 'Adam', 'Kaczmarczyk', 'ul. Długa 4, Lublin', '999000111', 'adam.kaczmarczyk@example.com'),
  (20, 'Natalia', 'Zalewska', 'ul. Polna 2, Białystok', '111222333', 'natalia.zalewska@example.com'),
  (21, 'Marcin', 'Kowalczyk', 'ul. Leśna 9, Katowice', '444555666', 'marcin.kowalczyk@example.com'),
  (22, 'Dominika', 'Michalak', 'ul. Ogrodowa 6, Gdańsk', '777888999', 'dominika.michalak@example.com'),
  (23, 'Paweł', 'Jasiński', 'ul. Morska 11, Kraków', '222333444', 'pawel.jasinski@example.com'),
  (24, 'Iga', 'Adamczyk', 'ul. Dąbrowskiego 8, Warszawa', '999000111', 'iga.adamczyk@example.com'),
  (25, 'Rafał', 'Sadowski', 'ul. Mickiewicza 5, Wrocław', '111222333', 'rafal.sadowski@example.com'),
  (26, 'Joanna', 'Krawiec', 'ul. Jasna 7, Poznań', '555111222', 'joanna.krawiec@example.com'),
  (27, 'Kamil', 'Kubiak', 'ul. Słoneczna 4, Gdynia', '777888999', 'kamil.kubiak@example.com'),
  (28, 'Daria', 'Kaczmarek', 'ul. Cicha 3, Łódź', '222333444', 'daria.kaczmarek@example.com'),
  (29, 'Bartosz', 'Lis', 'ul. Wiosenna 10, Szczecin', '999000111', 'bartosz.lis@example.com'),
  (30, 'Magdalena', 'Wojciechowska', 'ul. Ogrodowa 9, Lublin', '111222333', 'magdalena.wojciechowska@example.com'),
  (31, 'Kacper', 'Nowakowski', 'ul. Leśna 5, Białystok', '444555666', 'kacper.nowakowski@example.com'),
  (32, 'Maja', 'Pawlak', 'ul. Polna 8, Katowice', '777888999', 'maja.pawlak@example.com'),
  (33, 'Krzysztof', 'Jaworski', 'ul. Długa 6, Gdańsk', '222333444', 'krzysztof.jaworski@example.com'),
  (34, 'Natalia', 'Witkowska', 'ul. Morska 3, Kraków', '999000111', 'natalia.witkowska@example.com'),
  (35, 'Michał', 'Sikorski', 'ul. Dąbrowskiego 10, Warszawa', '111222333', 'michal.sikorski@example.com'),
  (36, 'Aleksandra', 'Kwiatkowska', 'ul. Mickiewicza 7, Wrocław', '555111222', 'aleksandra.kwiatkowska@example.com'),
  (37, 'Filip', 'Walczak', 'ul. Jasna 2, Poznań', '777888999', 'filip.walczak@example.com'),
  (38, 'Nikola', 'Olszewska', 'ul. Słoneczna 9, Gdynia', '222333444', 'nikola.olszewska@example.com'),
  (39, 'Mateusz', 'Mazurek', 'ul. Cicha 6, Łódź', '999000111', 'mateusz.mazurek@example.com'),
  (40, 'Julia', 'Jankowska', 'ul. Wiosenna 4, Szczecin', '111222333', 'julia.jankowska@example.com'),
  (41, 'Maciej', 'Mazur', 'ul. Leśna 2, Lublin', '444555666', 'maciej.mazur@example.com'),
  (42, 'Gabriela', 'Kaczmarczyk', 'ul. Ogrodowa 11, Białystok', '777888999', 'gabriela.kaczmarczyk@example.com'),
  (43, 'Wiktoria', 'Lewandowska', 'ul. Polna 7, Katowice', '222333444', 'wiktoria.lewandowska@example.com'),
  (44, 'Adam', 'Jaworski', 'ul. Długa 5, Gdańsk', '999000111', 'adam.jaworski@example.com'),
  (45, 'Kornelia', 'Zając', 'ul. Morska 10, Kraków', '111222333', 'kornelia.zajac@example.com'),
  (46, 'Bartłomiej', 'Kowalski', 'ul. Dąbrowskiego 2, Warszawa', '555111222', 'bartlomiej.kowalski@example.com'),
  (47, 'Zuzanna', 'Adamczyk', 'ul. Mickiewicza 8, Wrocław', '777888999', 'zuzanna.adamczyk@example.com'),
  (48, 'Antoni', 'Szymański', 'ul. Jasna 3, Poznań', '222333444', 'antoni.szymanski@example.com'),
  (49, 'Laura', 'Krawczyk', 'ul. Słoneczna 6, Gdynia', '999000111', 'laura.krawczyk@example.com'),
  (50, 'Stanisław', 'Wójcik', 'ul. Cicha 11, Łódź', '111222333', 'stanislaw.wojcik@example.com');

-- Wypełnienie tabeli "Wycieczki" danymi
INSERT INTO Wycieczki (ID_wycieczki, Nazwa, Opis, Data_rozpoczęcia, Data_zakończenia, Cena, Miejsca)
VALUES
  (1, 'Wakacje na Malediwach', 'Relaksujące wakacje na rajskich plażach Malediwów', '2023-07-10', '2023-07-20', 3500.00, 15),
  (2, 'Odkrywanie Rzymu', 'Wycieczka po zabytkach i kulturze Rzymu', '2023-08-15', '2023-08-22', 2500.00, 25),
  (3, 'Podróż do Paryża', 'Zwiedzanie romantycznego Paryża i jego atrakcji', '2023-09-05', '2023-09-12', 2800.00, 50),
  (4, 'Safari w Afryce', 'Niezapomniana przygoda na safari w afrykańskiej dziczy', '2023-07-25', '2023-08-05', 4100.00,40),
  (5, 'Wycieczka do Tajlandii', 'Odkrywanie kultury i piękna Tajlandii', '2023-08-10', '2023-08-20', 3200.00,40),
  (6, 'Relaks nad Morzem Śródziemnym', 'Wakacje pełne słońca i wypoczynku na wybrzeżu Morza Śródziemnego', '2023-09-15', '2023-09-22', 2400.00,40),
  (7, 'Wycieczka po Europie Zachodniej', 'Zwiedzanie wielu europejskich stolic i zabytków', '2023-07-15', '2023-07-30', 5200.00,40),
  (8, 'Wakacje na Hawajach', 'Poznanie uroków i piękna Hawajów', '2023-08-05', '2023-08-15', 3800.00,40),
  (9, 'Wycieczka do Egiptu', 'Odkrywanie starożytnych skarbów Egiptu', '2023-09-10', '2023-09-20', 2900.00,40),
  (10, 'Zwiedzanie Chin', 'Podróż po fascynujących zakątkach Chin', '2023-07-20', '2023-08-05', 4500.00,40),
  (11, 'Wycieczka do Australii', 'Przygoda w egzotycznym świecie Australii', '2023-08-25', '2023-09-05', 5600.00,40),
  (12, 'Wakacje na Karaibach', 'Relaksujące wakacje na rajskich plażach Karaibów', '2023-09-15', '2023-09-25', 3200.00,40),
  (13, 'Zwiedzanie Japonii', 'Odkrywanie fascynującej kultury i tradycji Japonii', '2023-07-30', '2023-08-10', 4100.00,40),
  (14, 'Wycieczka po Ameryce Południowej', 'Przejażdżka przez malownicze krajobrazy Ameryki Południowej', '2023-08-10', '2023-08-25', 4800.00,40),
  (15, 'Wakacje na Malcie', 'Słoneczne wakacje na urokliwej wyspie Malta', '2023-09-05', '2023-09-12', 2600.00,40),
  (16, 'Wycieczka po Skandynawii', 'Zwiedzanie pięknych zakątków Skandynawii', '2023-07-25', '2023-08-05', 3900.00,40),
  (17, 'Podróż do Grecji', 'Odkrywanie antycznych ruin i greckiej kultury', '2023-08-15', '2023-08-25', 3200.00,40),
  (18, 'Safari w Kenii', 'Niezapomniane safari w sercu afrykańskiej przyrody', '2023-09-10', '2023-09-20', 4200.00,40),
  (19, 'Wycieczka do Hiszpanii', 'Zwiedzanie słonecznej Hiszpanii i jej uroków', '2023-07-10', '2023-07-20', 2900.00,40),
  (20, 'Relaks na Seszelach', 'Wypoczynek na rajskich plażach Seszeli', '2023-08-05', '2023-08-15', 3600.00,40),
  (21, 'Wakacje w Portugalii', 'Słońce, plaże i kultura Portugalii', '2023-09-05', '2023-09-15', 2700.00,40),
  (22, 'Wycieczka po USA', 'Podróż przez różnorodne regiony Stanów Zjednoczonych', '2023-07-15', '2023-07-30', 5500.00,40),
  (23, 'Podróż do Nowej Zelandii', 'Odkrywanie piękna i przygód Nowej Zelandii', '2023-08-20', '2023-09-05', 5900.00,40),
  (24, 'Wycieczka do Islandii', 'Przygoda w lodowej krainie Islandii', '2023-09-10', '2023-09-20', 4300.00,40),
  (25, 'Zwiedzanie Włoch', 'Odkrywanie sztuki, kultury i kuchni włoskiej', '2023-07-20', '2023-08-05', 3800.00,40),
  (26, 'Wakacje na Bali', 'Relaks i odprężenie na pięknej wyspie Bali', '2023-08-25', '2023-09-05', 3200.00,40),
  (27, 'Wycieczka po Rosji', 'Zwiedzanie największego kraju świata i jego zabytków', '2023-09-15', '2023-09-25', 4500.00,40),
  (28, 'Wakacje na Wyspach Kanaryjskich', 'Słoneczne wakacje na wyspach Kanaryjskich', '2023-07-30', '2023-08-10', 2900.00,40),
  (29, 'Wycieczka po Ameryce Środkowej', 'Przejażdżka przez egzotyczne kraje Ameryki Środkowej', '2023-08-10', '2023-08-25', 4300.00,40),
  (30, 'Podróż do Maroka', 'Odkrywanie magii i kolorów Maroka', '2023-09-05', '2023-09-12', 2500.00,40),
  (31, 'Zwiedzanie Austrii', 'Podróż przez malownicze krajobrazy i zabytki Austrii', '2023-07-25', '2023-08-05', 3200.00,40),
  (32, 'Wakacje na Mauritiusie', 'Relaks na rajskich plażach Mauritiusa', '2023-08-15', '2023-08-25', 3900.00,40),
  (33, 'Wycieczka do Norwegii', 'Odkrywanie piękna norweskich fiordów i natury', '2023-09-10', '2023-09-20', 4800.00,40),
  (34, 'Podróż do Turcji', 'Zwiedzanie fascynujących zakątków i historii Turcji', '2023-07-10', '2023-07-20', 2600.00,40),
  (35, 'Relaks na Maderze', 'Wypoczynek na urokliwej wyspie Madera', '2023-08-05', '2023-08-15', 3400.00,40),
  (36, 'Wycieczka po Gruzji', 'Zwiedzanie pięknych zakątków Gruzji i degustacja wina', '2023-09-05', '2023-09-15', 2900.00,40),
  (37, 'Wakacje w Szwecji', 'Relaks i wypoczynek w pięknej Szwecji', '2023-07-15', '2023-07-30', 3200.00,40),
  (38, 'Wycieczka do Indii', 'Odkrywanie tajemnic Indii i ich kultury', '2023-08-20', '2023-09-05', 4200.00,40),
  (39, 'Podróż do Kanady', 'Zwiedzanie malowniczych zakątków i przyrody Kanady', '2023-09-10', '2023-09-20', 5200.00,40),
  (40, 'Zwiedzanie Szkocji', 'Podróż przez mistyczną Szkocję i jej zabytki', '2023-07-20', '2023-08-05', 3800.00,40),
  (41, 'Wakacje na Krecie', 'Relaks na pięknej greckiej wyspie Kreta', '2023-08-25', '2023-09-05', 3200.00,40),
  (42, 'Wycieczka po Brazylii', 'Przejażdżka przez malownicze krajobrazy Brazylii', '2023-09-15', '2023-09-25', 4700.00,40),
  (43, 'Wakacje na Sycylii', 'Słońce, morze i piękne plaże Sycylii', '2023-07-30', '2023-08-10', 2800.00,40),
  (44, 'Wycieczka po Azji Południowo-Wschodniej', 'Odkrywanie różnorodności kulturowej i przyrodniczej Azji Południowo-Wschodniej', '2023-08-10', '2023-08-25', 3900.00,40),
  (45, 'Podróż do Wietnamu', 'Zwiedzanie fascynujących zakątków Wietnamu', '2023-09-05', '2023-09-12', 2700.00,40),
  (46, 'Zwiedzanie Holandii', 'Odkrywanie uroków Holandii i jej zabytków', '2023-07-25', '2023-08-05', 3300.00,40),
  (47, 'Wakacje na Korsyce', 'Relaks i wypoczynek na urokliwej wyspie Korsyka', '2023-08-15', '2023-08-25', 3500.00,40),
  (48, 'Wycieczka po Chorwacji', 'Zwiedzanie malowniczych miast i wybrzeża Chorwacji', '2023-09-10', '2023-09-20', 4400.00,40),
  (49, 'Podróż do Tajlandii', 'Odkrywanie kultury i piękna Tajlandii', '2023-07-10', '2023-07-20', 3200.00,40),
  (50, 'Relaks na Mauritiusie', 'Wypoczynek na rajskich plażach Mauritiusa', '2023-08-05', '2023-08-15', 3800.00,40);

-- Wypełnienie tabeli "Hotele" danymi
INSERT INTO Hotele (ID_hotelu, Nazwa, Adres, Miasto, Kraj, Ocena, Cena_za_noc) 
VALUES
  (1, 'Hotel Paradise', 'ul. Słoneczna 10', 'Kraków', 'Polska', 8.5, 200.00),
  (2, 'Grand Hotel', 'ul. Piękna 5', 'Warszawa', 'Polska', 9.2, 350.00),
  (3, 'Seaside Resort', '123 Beach Street', 'Miami', 'USA', 8.8, 400.00),
  (4, 'Mountain View Lodge', 'Mountain Road 20', 'Vancouver', 'Kanada', 8.0, 300.00),
  (5, 'Hotel Bella Vista', 'Via Roma 15', 'Rzym', 'Włochy', 9.5, 250.00),
  (6, 'Beachfront Resort', 'Sunset Boulevard 50', 'Los Angeles', 'USA', 8.7, 450.00),
  (7, 'City Center Hotel', 'Main Street 1', 'Londyn', 'Wielka Brytania', 9.0, 280.00),
  (8, 'Tropical Paradise Resort', 'Palm Avenue 25', 'Bali', 'Indonezja', 8.9, 350.00),
  (9, 'Alpine Chalet', 'Mountain View 5', 'Zermatt', 'Szwajcaria', 9.3, 500.00),
  (10, 'Beachside Hotel', 'Coastal Road 10', 'Sydney', 'Australia', 8.4, 380.00),
  (11, 'Historic Inn', 'Old Town Square 2', 'Praga', 'Czechy', 8.2, 220.00),
  (12, 'Lakeview Resort', 'Lake Road 8', 'Toronto', 'Kanada', 8.6, 320.00),
  (13, 'City Lights Hotel', 'Downtown Avenue 15', 'Nowy Jork', 'USA', 9.1, 450.00),
  (14, 'Cozy Cottage', 'Green Lane 3', 'Lizbona', 'Portugalia', 8.8, 180.00),
  (15, 'Oceanfront Hotel', 'Seaview Road 12', 'Gold Coast', 'Australia', 8.5, 400.00),
  (16, 'Mountain Retreat', 'Alpine Way 7', 'Denver', 'USA', 8.3, 300.00),
  (17, 'Harbour View Hotel', 'Harbour Street 20', 'Hongkong', 'Chiny', 9.4, 420.00),
  (18, 'Countryside Resort', 'Meadow Lane 30', 'Kapsztad', 'Południowa Afryka', 8.7, 380.00),
  (19, 'Seaview Inn', 'Coastal Avenue 8', 'Barcelona', 'Hiszpania', 9.0, 280.00),
  (20, 'Skyline Hotel', 'High Street 10', 'Tokio', 'Japonia', 8.9, 360.00),
  (21, 'Riverside Lodge', 'River Road 5', 'Amsterdam', 'Holandia', 9.3, 320.00),
  (22, 'Beach Retreat', 'Sandy Beach 15', 'Hawaje', 'USA', 8.4, 420.00),
  (23, 'Hillside Resort', 'Mountain Lane 12', 'Kapsztad', 'Południowa Afryka', 8.8, 380.00),
  (24, 'City View Hotel', 'Downtown Street 25', 'Singapur', 'Singapur', 8.7, 350.00),
  (25, 'Garden Oasis', 'Green Avenue 10', 'Lima', 'Peru', 8.2, 250.00),
  (26, 'Alpine Lodge', 'Mountain Road 8', 'Zakopane', 'Polska', 9.1, 280.00),
  (27, 'Island Paradise Resort', 'Palm Beach 20', 'Bora Bora', 'Polinezja Francuska', 9.7, 600.00),
  (28, 'Luxury Suites', 'Central Square 5', 'Dubaj', 'Zjednoczone Emiraty Arabskie', 9.5, 800.00),
  (29, 'Riverfront Hotel', 'River Street 15', 'Chicago', 'USA', 8.6, 350.00),
  (30, 'Charming Inn', 'Old Town Lane 3', 'Bruksela', 'Belgia', 8.4, 240.00),
  (31, 'Seaside Cottage', 'Beach Road 12', 'Neapol', 'Włochy', 8.9, 320.00),
  (32, 'City Tower Hotel', 'Skyscraper Avenue 1', 'Szanghaj', 'Chiny', 9.2, 420.00),
  (33, 'Mountain View Hotel', 'Hillside Road 8', 'Kapsztad', 'Południowa Afryka', 8.7, 380.00),
  (34, 'Sunset Resort', 'Sunset Boulevard 30', 'Los Angeles', 'USA', 8.5, 450.00),
  (35, 'Urban Oasis', 'City Center 10', 'Nowy Jork', 'USA', 9.0, 320.00),
  (36, 'Beachfront Villa', 'Coastal Lane 5', 'Sydney', 'Australia', 9.3, 550.00),
  (37, 'Historic Mansion', 'Old Town Square 20', 'Praga', 'Czechy', 8.8, 280.00),
  (38, 'Lakefront Resort', 'Lakeview Avenue 8', 'Toronto', 'Kanada', 8.6, 350.00),
  (39, 'Cityscape Hotel', 'Downtown Street 12', 'Nowy Jork', 'USA', 9.1, 400.00),
  (40, 'Cosy Cabin', 'Forest Road 15', 'Lizbona', 'Portugalia', 8.8, 200.00),
  (41, 'Beachside Retreat', 'Seashore Lane 10', 'Gold Coast', 'Australia', 8.5, 380.00),
  (42, 'Mountain Lodge', 'Alpine Road 5', 'Denver', 'USA', 8.3, 280.00),
  (43, 'Harbour Hotel', 'Harbour Road 20', 'Hongkong', 'Chiny', 9.4, 400.00),
  (44, 'Country Manor', 'Country Lane 30', 'Kapsztad', 'Południowa Afryka', 8.7, 350.00),
  (45, 'Sea Breeze Inn', 'Coastal Road 8', 'Barcelona', 'Hiszpania', 9.0, 320.00),
  (46, 'Skyline Hotel', 'Highway Avenue 10', 'Tokio', 'Japonia', 8.9, 380.00),
  (47, 'Riverfront Lodge', 'River Lane 5', 'Amsterdam', 'Holandia', 9.3, 280.00),
  (48, 'Beachfront Retreat', 'Sandy Beach 15', 'Hawaje', 'USA', 8.4, 450.00),
  (49, 'Mountain Resort', 'Mountain Avenue 12', 'Kapsztad', 'Południowa Afryka', 8.8, 400.00),
  (50, 'City Lights Hotel', 'Downtown Avenue 25', 'Singapur', 'Singapur', 8.7, 380.00);

-- Wypełnienie tabeli "Przewoźnicy" danymi
INSERT INTO Przewoźnicy (ID_przewoźnika, Nazwa, Adres, Miasto, Kraj, Ocena) 
VALUES
  (1, 'AirWorld', 'ul. Lotnicza 10', 'Kraków', 'Polska', 8.5),
  (2, 'FlyGlobal', 'ul. Aviatorska 5', 'Warszawa', 'Polska', 9.2),
  (3, 'OceanAir', '123 Sea Street', 'Miami', 'USA', 8.8),
  (4, 'Skyline Airlines', 'Cloud Avenue 20', 'Los Angeles', 'USA', 8.7),
  (5, 'Wings of the World', 'Flight Road 15', 'Londyn', 'Wielka Brytania', 9.0),
  (6, 'Island Airways', 'Palm Beach 25', 'Bali', 'Indonezja', 8.9),
  (7, 'Alpine Air', 'Mountain View 5', 'Zermatt', 'Szwajcaria', 9.3),
  (8, 'AeroJet', 'Jet Avenue 10', 'Sydney', 'Australia', 8.4),
  (9, 'EuroWings', 'Sky Street 2', 'Berlin', 'Niemcy', 8.6),
  (10, 'Mediterranean Airlines', 'Seafront Road 8', 'Ateny', 'Grecja', 8.8),
  (11, 'TransGlobal', 'ul. Lotnicza 20', 'Warszawa', 'Polska', 8.9),
  (12, 'AirConnect', 'ul. Aviation 15', 'Kraków', 'Polska', 9.1),
  (13, 'Sunrise Airways', 'Sunset Boulevard 10', 'Los Angeles', 'USA', 8.7),
  (14, 'Atlantic Airlines', 'Beach Road 12', 'Miami', 'USA', 8.6),
  (15, 'AirVoyage', 'ul. Aerial 8', 'Paryż', 'Francja', 9.0),
  (16, 'JetLink', 'Jet Road 5', 'Berlin', 'Niemcy', 8.3),
  (17, 'GlobalSky', 'ul. Aviation 25', 'Londyn', 'Wielka Brytania', 9.2),
  (18, 'SeaBreeze Airlines', 'Beachfront Avenue 8', 'Bali', 'Indonezja', 8.9),
  (19, 'MountainAir', 'Mountain Road 15', 'Zermatt', 'Szwajcaria', 9.4),
  (20, 'Pacific Wings', 'Pacific Street 10', 'Sydney', 'Australia', 8.5),
  (21, 'EuroConnect', 'ul. Aviation 20', 'Warszawa', 'Polska', 8.7),
  (22, 'AirQuest', 'ul. Flight 5', 'Kraków', 'Polska', 9.3),
  (23, 'Sunny Airlines', 'Sunset Boulevard 15', 'Miami', 'USA', 8.8),
  (24, 'AirBridge', 'Bridge Road 12', 'Los Angeles', 'USA', 8.6),
  (25, 'AeroWorld', 'ul. Aviatorska 8', 'Londyn', 'Wielka Brytania', 9.1),
  (26, 'Tropical Airways', 'Palm Beach 20', 'Bali', 'Indonezja', 8.5),
  (27, 'Mountain Wings', 'Mountain View 10', 'Zermatt', 'Szwajcaria', 9.0),
  (28, 'SkyTravel', 'ul. Aerial 15', 'Berlin', 'Niemcy', 8.8),
  (29, 'MediterraJet', 'Seafront Road 12', 'Ateny', 'Grecja', 8.7),
  (30, 'TransAero', 'ul. Lotnicza 5', 'Warszawa', 'Polska', 8.6),
  (31, 'AirGlobe', 'ul. Aviation 10', 'Kraków', 'Polska', 9.2),
  (32, 'Sunset Airways', 'Sunset Boulevard 20', 'Miami', 'USA', 8.9),
  (33, 'Atlantic Connect', 'Beach Road 8', 'Los Angeles', 'USA', 8.7),
  (34, 'AeroVoyage', 'ul. Aerial 5', 'Paryż', 'Francja', 9.3),
  (35, 'JetExpress', 'Jet Road 10', 'Berlin', 'Niemcy', 8.5),
  (36, 'GlobalConnect', 'ul. Aviation 15', 'Londyn', 'Wielka Brytania', 9.1),
  (37, 'Beachline Airlines', 'Beachfront Avenue 10', 'Bali', 'Indonezja', 8.6),
  (38, 'Alpine Wings', 'Mountain Road 8', 'Zermatt', 'Szwajcaria', 9.5),
  (39, 'Pacific Connect', 'Pacific Street 15', 'Sydney', 'Australia', 8.7),
  (40, 'EuroLink', 'ul. Aviation 25', 'Warszawa', 'Polska', 9.0),
  (41, 'AirQuest', 'ul. Flight 8', 'Kraków', 'Polska', 8.8),
  (42, 'Sunny Air', 'Sunset Boulevard 12', 'Miami', 'USA', 8.5),
  (43, 'AirBridge', 'Bridge Road 15', 'Los Angeles', 'USA', 8.9),
  (44, 'AeroGlobe', 'ul. Aviatorska 10', 'Londyn', 'Wielka Brytania', 9.2),
  (45, 'Tropical Connect', 'Palm Beach 25', 'Bali', 'Indonezja', 8.7),
  (46, 'Mountain Airways', 'Mountain View 12', 'Zermatt', 'Szwajcaria', 9.3),
  (47, 'SkyLine', 'ul. Aerial 10', 'Berlin', 'Niemcy', 8.6),
  (48, 'MediterraJet', 'Seafront Road 10', 'Ateny', 'Grecja', 8.5),
  (49, 'TransWorld', 'ul. Lotnicza 8', 'Warszawa', 'Polska', 9.1),
  (50, 'AirGlobe', 'ul. Aviation 12', 'Kraków', 'Polska', 8.7);

-- Wypełnienie tabeli "Rezerwacje" danymi
INSERT INTO Rezerwacje (ID_rezerwacji, ID_klienta, ID_wycieczki, ID_hotelu, ID_przewoźnika, Data_rezerwacji, Ilość_osób, Cena)
VALUES
  (1, 1, 1, 1, 1, '2023-06-01', 2, 2650.00),
  (2, 2, 2, 2, 2, '2023-06-02', 1, 2650.00),
  (3, 3, 3, 3, 3, '2023-06-03', 4, 2650.00),
  (4, 4, 4, 4, 4, '2023-06-04', 2, 2650.00),
  (5, 5, 5, 5, 5, '2023-06-05', 3, 2650.00),
  (6, 6, 6, 6, 6, '2023-06-06', 1, 2650.00),
  (7, 7, 7, 7, 7, '2023-06-07', 2, 2650.00),
  (8, 8, 8, 8, 8, '2023-06-08', 2, 2650.00),
  (9, 9, 9, 9, 9, '2023-06-09', 3, 2650.00),
  (10, 10, 10, 10, 10, '2023-06-10', 1, 2650.00),
  (11, 11, 11, 11, 11, '2023-06-11', 2, 2650.00),
  (12, 12, 12, 12, 12, '2023-06-12', 2, 2650.00),
  (13, 13, 13, 13, 13, '2023-06-13', 1, 2650.00),
  (14, 14, 14, 14, 14, '2023-06-14', 4, 2650.00),
  (15, 15, 15, 15, 15, '2023-06-15', 2, 2650.00),
  (16, 16, 16, 16, 16, '2023-06-16', 1, 2650.00),
  (17, 17, 17, 17, 17, '2023-06-17', 3, 2650.00),
  (18, 18, 18, 18, 18, '2023-06-18', 2, 2650.00),
  (19, 19, 19, 19, 19, '2023-06-19', 1, 2650.00),
  (20, 20, 20, 20, 20, '2023-06-20', 2, 4560.00);

-- 1. WHERE
SELECT *
FROM Klienci, Rezerwacje, Wycieczki
WHERE Klienci.ID_klienta = Rezerwacje.ID_klienta AND Rezerwacje.ID_wycieczki = Wycieczki.ID_wycieczki;

-- 2. NATURAL JOIN
SELECT *
FROM Klienci
NATURAL JOIN Rezerwacje
NATURAL JOIN Wycieczki;

-- 3. INNER JOIN
SELECT *
FROM Klienci
INNER JOIN Rezerwacje ON Klienci.ID_klienta = Rezerwacje.ID_klienta
INNER JOIN Wycieczki ON Rezerwacje.ID_wycieczki = Wycieczki.ID_wycieczki;

-- 4. LEFT OUTER JOIN
SELECT *
FROM Klienci
LEFT OUTER JOIN Rezerwacje ON Klienci.ID_klienta = Rezerwacje.ID_klienta
LEFT OUTER JOIN Wycieczki ON Rezerwacje.ID_wycieczki = Wycieczki.ID_wycieczki;

-- 5. RIGHT OUTER JOIN
SELECT *
FROM Klienci
RIGHT OUTER JOIN Rezerwacje ON Klienci.ID_klienta = Rezerwacje.ID_klienta
RIGHT OUTER JOIN Wycieczki ON Rezerwacje.ID_wycieczki = Wycieczki.ID_wycieczki;

-- Zapytanie z klauzulą GROUP BY i funkcją SUM
SELECT Rezerwacje.ID_wycieczki, SUM(Wycieczki.Cena) AS SumaCen
FROM Rezerwacje 
INNER JOIN Wycieczki ON Rezerwacje.ID_wycieczki = Wycieczki.ID_wycieczki
GROUP BY ID_wycieczki;

-- Zapytanie z klauzulą HAVING i funkcją COUNT
SELECT ID_wycieczki, COUNT(*) AS LiczbaRezerwacji
FROM Rezerwacje
GROUP BY ID_wycieczki
HAVING COUNT(*) > 5;

-- Zapytanie z klauzulą BETWEEN
SELECT *
FROM Wycieczki
WHERE Data_rozpoczęcia BETWEEN '2023-06-01' AND '2023-07-31';

-- Zapytanie z klauzulą LIKE
SELECT *
FROM Klienci
WHERE Nazwisko LIKE 'Kow%';

-- Zapytanie z klauzulą ORDER BY
SELECT *
FROM Wycieczki
ORDER BY Cena DESC;
**Tarifs Misy 2.0 (confidentiel)**

Ceci est un document interne à Misy. Ni son contenu, ni les détails, ni le document en lui-même ne seront communiqués ou diffusés à des personnes extérieures à Misy (chauffeurs compris) sans l’accord de la direction

1. # Nouveaux tarifs

|  | Taxi-moto | Classic | Confort | 4x4 | Van |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Prix plancher**  | 6000 | 8000 | 11000 | 13000 | 15000 |
| **Prix du km** | 2000 | 2750 | 3850 | 4500 | 5000 |

**Prix plancher:** Il s’agit du prix invariable de la course **jusqu’à 3 km**. Passé cette limite, le prix de la course est calculé en fonction du nombre de kilomètres parcourus

**Variables ajustables:**

* Km max pour le prix plancher  
* Prix du km pour toutes les catégories

2. # Majorations

   1. **Embouteillages**

Pendant les bouchons, le prix sera majoré de 40% (x1.4)  
Les périodes de majorations sont fixées à l’avance: **7h00-9h59 et 16h00-18h59**

**Variables ajustables:** 

* Multiplicateur du prix  
* Plages horaires des majorations

  2. **Courses longues**

Les courses longues éloignant le chauffeur des lieux où se trouvent généralement les clients, il semble nécessaire d’imposer une majoration du prix à partir d’un certain nombre de km pour assurer l’attractivité de ces courses pour les chauffeurs.

**Formule initiale :**

| *Prix \= (Prix au km Normal × Seuil De Course Longue) \+ \[(Distance − Seuil de course longue) × Prix au km normal × Majoration\]* |
| :---: |

**Avec:**   
**Prix au km normal** : tarif standard appliqué par kilomètre.  
**Distance** : distance totale de la course (en km).  
**Variables ajustables:**  
**Seuil de course longue** : distance (en km) à partir de laquelle une majoration s'applique.  
**Majoration** : coefficient multiplicateur appliqué au tarif au-delà du seuil 

**Formule factorisée:**

| *Prix=prix\_km×\[seuil+(distance−seuil)×majoration\]* |
| :---: |

**Propositions:**   
**Seuil de course longue** : **15 km**  
**Majoration : 1.2**

Soit:

| *Prix \= prix\_km × \[15+(distance−15)×1.2\]* |
| :---: |

3. # Réservation

Les courses réservées exigent que le chauffeur soit déjà sur place x minutes à l’avance. Les projections de revenus estiment un CA moyen de 30000 MGA par heure pour les courses Misy classic. Avec ces données et les ratios de tarifs vs classic, il est donc possible de calculer le surcoût à payer pour la réservation d’une course.

| Temps d'avance exigé | 10 | 15 | 20 |
| :---- | ----: | ----: | ----: |
| **Surcoût Taxi-moto** | 3600 | 5500 | 7300 |
| **Surcoût Classic** | 5000 | 7500 | 10000 |
| **Surcoût Confort** | 7000 | 10500 | 14000 |
| **Surcoût 4x4** | 8200 | 12300 | 16400 |
| **Surcoût Van** | 9100 | 13600 | 18200 |

**⚠️A nous maintenant de fixer le temps d’avance exigé ⚠️**

4. # Arrondis

Pour simplifier les paiements en espèce, il serait peut-être préférable d’arrondir les prix à 500 MGA près (ex: 15200 MGA \= 15000 MGA; 7800 MGA \= 8000 MGA)

5. # Résumé

     
* **Formule prix:**

| Distance d |  d \< 3 | 3 \< d \< 15 | d \> 15 |
| :---- | :---- | :---- | :---- |
| **Prix** | **Prix plancher**  | **prix\_km x d** | **prix\_km × \[15+( d −15)×1.2\]** |


* **Tarifs des catégories**

|  | Taxi-moto | Classic | Confort | 4x4 | Van |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Prix plancher**  | 6000 | 8000 | 11000 | 13000 | 15000 |
| **Prix du km** | 2000 | 2750 | 3850 | 4500 | 5000 |

* **Bouchons**

Majoration bouchons: **x1.4**  
Plages horaires des majorations: **7h00-9h59 et 16h00-18h59**

* **Réservation**

**Prix \= Prix normal \+ Surcoût réservation**

* **Liste des variables ajustables**

Prix plancher  
	Taxi-moto  
	Classic  
	Confort  
	4x4  
	Van  
Seuil max prix plancher  
Prix\_km  
	Taxi-moto  
	Classic  
	Confort  
	4x4  
	Van  
Majoration bouchons  
Plages horaires majoration bouchons  
Seuil de course longue  
Majoration course longue  
	Taxi-moto  
	Classic  
	Confort  
	4x4  
	Van  
Surcoût réservation  
	Taxi-moto  
	Classic  
	Confort  
	4x4  
	Van  

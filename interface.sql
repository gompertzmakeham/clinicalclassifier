CREATE OR REPLACE PACKAGE syphilisclassifier AS
/*
 *  Stub package outlining the meta-framework for implementing clinical classification
 *  algorithms as Mealy finite state transducer. The theory behind this implementation is
 *  that clinical classification is a stochastic process adapted to the filteration of the
 *  sigma-algebra refinements by sequential clinical observation. However, clinicians know
 *  a priori how many observations they have requested and will only make a decision after
 *  recieving the all the order observations. Unfortunately those inter-observation
 *  relationships are rarely recorded in our longitudinal data sets. As a heuristic to
 *  address this limitation we implement the decision proceess with a preemptive transducer
 *  that determines if a clinical observation should be produced by comparing the current
 *  state to the incoming observation that will drive the change in state. This allows, for
 *  example, classifications to be produced only at the end of the day, or the change in the
 *  patient. This is the simplest possible Mealy dependency as only the existence of an
 *  output depends on the transition, the actual values are transduced from the state.
 *
 *  This package is a working example that implements the toy model of:
 *
 *    susceptible -> new infection -> continued infection -> remission -> reinfection
 *
 *  The internal state counts infections based of an asborbing detector of positive assays.
 */

	/*
	 *  A single type of clinical observation of a single patient at a single time, add
	 *  fields as necessary to describe the type of observation and results.
	 */
	TYPE inputobservation IS RECORD
	(
		uliabphn INTEGER,
		assaydate DATE,
		assayidentifier VARCHAR2(16),
    assaydescription VARCHAR2(64),
		resultdescription VARCHAR2(64),
    assayorder VARCHAR2(16),
    assayresult INTEGER
	);

	/*
	 *  A courtesy collection of observatons for each patient. Not used.
	 */
	TYPE inputobservations IS TABLE OF inputobservation;

	/*
	 *  A representation of the state of the patient based on the history of that patient to 
	 *  the current point in time, add fields as necessary to describe the state.
	 */
	TYPE outputclassification IS RECORD
	(
		uliabphn INTEGER,
		classificationdate DATE,
    infectioncount INTEGER,
		infectionstatus VARCHAR2(32)
	);

	/*
	 *  A collection of resulting states for each patient.
	 */
	TYPE outputclassifications IS TABLE OF outputclassification;

	/*
	 *  Internal intermediate state used to propagate the patients current state from the
	 *  current observation to the next
	 */
	TYPE internalstate IS RECORD
	(
		uliabphn INTEGER,
		statedate DATE,
		patientinfections INTEGER,
		currentinfected INTEGER,
		previousinfected INTEGER,
    currentdilution INTEGER,
    previousdilution INTEGER,
    EIAtrigger INTEGER,
    TPPAtrigger INTEGER,
    RPRtrigger INTEGER
	);

	/*
	 *  A courtesy collection of internal intermediate states for each patient. Not used.
	 */
	TYPE internalstates IS TABLE OF internalstate;

	/*
	 *  Wrapper for the SQL statement that lists all the relavent clinical observations in the
	 *  order that they occurred.
	 */
	CURSOR generateobservation RETURN inputobservation;

	/*
	 *  Loop through the clinical observations as they occurred and update the state of the
	 *  patient. There should be no need to edit this loop.
	 */
	FUNCTION generateclassification RETURN outputclassifications PIPELINED;

	/*
	 *  Overloaded production rules implementing the clinical decision algorithm at a single
	 *  point in time. Create the starting state before entrance to the loop.
	 */
	FUNCTION producestate RETURN internalstate;

	/*
	 *  Overloaded production rules implementing the clinical decision algorithm at a single
	 *  point in time. Maps the current internal state and the next observation to the next
	 *  internal state. Place all the clinical logic in this function.
	 */
	FUNCTION producestate
	(
		currentstate internalstate,
		nextobservation inputobservation
	)
	RETURN internalstate;

	/*
	 *  Overloaded transduction of the internal intermediate state to the output clinical
	 *  classification, this tests if a classification should be reported.
	 */
	FUNCTION transduceclassification
	(
		currentstate internalstate,
		nextobservation inputobservation
	)
	RETURN BOOLEAN;

	/*
	 *  Overloaded transduction of the internal intermediate state to the output clinical
	 *  classification, this produces the actual classification.
	 */
	FUNCTION transduceclassification
	(
		currentstate internalstate
	)
	RETURN outputclassification;
END syphilisclassifier;
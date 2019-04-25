CREATE OR REPLACE PACKAGE BODY clinicalclassifier AS
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
	 *  Wrapper for the SQL statement that lists all the relavent clinical observations in the
	 *  order that they occurred.
	 */
	CURSOR generateobservation RETURN inputobservation IS
	SELECT
		1 uliabphn,
		TRUNC(SYSDATE) assaydate,
		'MC' assayidentifier,
		'Microbial Culture' assaydescription,
		0 assaycolonies,
		'N' resultidentifier,
		'Negative' resultdescription
	FROM
		dual a0
	UNION ALL	
	SELECT
		1 uliabphn,
		TRUNC(SYSDATE) assaydate,
		'MC' assayidentifier,
		'Microbial Culture' assaydescription,
		1 assaycolonies,
		'P' resultidentifier,
		'Positive' resultdescription
	FROM
		dual a0
	ORDER BY
		1 ASC NULLS FIRST,
		2 ASC NULLS FIRST,
		5 ASC NULLS FIRST;

	/*
	 *  Loop through the clinical observations as they occurred and update the state of the
	 *  patient. There should be no need to edit this loop.
	 */
	FUNCTION generateclassification RETURN outputclassifications PIPELINED AS
		currentstate internalstate := producestate;
	BEGIN

		-- Step through the observations in the order they occurred updating the internal state
		-- according to the production rules and reporting
		FOR nextobservation IN generateobservation LOOP
			IF transduceclassification(currentstate, nextobservation) THEN
				PIPE ROW (transduceclassification(currentstate));
			END IF;
			currentstate := producestate(currentstate, nextobservation);
		END LOOP;
		PIPE ROW (transduceclassification(currentstate));
		
		-- Empty exit
		RETURN;
	END generateclassification;

	/*
	 *  Overloaded production rules implementing the clinical decision algorithm at a single
	 *  point in time. Create the starting state before entrance to the loop.
	 */
	FUNCTION producestate RETURN internalstate AS
		nextstate internalstate;
	BEGIN

		-- Minimal initialization, edit as necessary
		nextstate.uliabphn := 0;
		nextstate.statedate := TRUNC(SYSDATE);
		nextstate.patientinfections := 0;
		nextstate.currentinfected := 0;
		nextstate.previousinfected := 0;
	
		-- Send
		RETURN nextstate;
	END producestate;

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
	RETURN internalstate AS
		nextstate internalstate;
	BEGIN

		-- Propagate basic identifiers
		nextstate.uliabphn := nextobservation.uliabphn;
		nextstate.statedate := nextobservation.assaydate;

		-- Determine the type of action
		CASE

			-- Process new patient, resetting flags and counters
			WHEN currentstate.uliabphn < nextobservation.uliabphn THEN
				nextstate.patientinfections := 0;
				nextstate.currentinfected := 0;
				nextstate.previousinfected := 0;

			-- Process new date for the same patient, begin day by assuming negative assays
			WHEN currentstate.statedate < nextobservation.assaydate THEN
				nextstate.patientinfections := currentstate.patientinfections;
				nextstate.currentinfected := 0;
				nextstate.previousinfected := currentstate.currentinfected;

			-- Pull forward observations for the same date and patient
			ELSE
				nextstate.patientinfections := currentstate.patientinfections;
				nextstate.currentinfected := currentstate.currentinfected;
				nextstate.previousinfected := currentstate.previousinfected;
		END CASE;

		-- Update infection status on first positive test of the day
		IF nextobservation.assaycolonies > 0 AND nextstate.currentinfected < 1 THEN
			nextstate.patientinfections := 1 + nextstate.patientinfections;
			nextstate.currentinfected := 1;
		END IF;

		-- Send
		RETURN nextstate;
	END producestate;

	/*
	 *  Overloaded transduction of the internal intermediate state to the output clinical
	 *  classification, this tests if a classification should be reported.
	 */
	FUNCTION transduceclassification
	(
		currentstate internalstate,
		nextobservation inputobservation
	)
	RETURN BOOLEAN AS
	BEGIN

		-- Determine the type of action
		CASE
		
			-- Very first record, do not produce classification
			WHEN currentstate.uliabphn < 1 THEN
				RETURN FALSE;

			-- Incoming new patient, produce classification for current patient
			WHEN currentstate.uliabphn < nextobservation.uliabphn THEN
				RETURN TRUE;

			-- Incoming new day, produce classification for current day
			WHEN currentstate.statedate < nextobservation.assaydate THEN
				RETURN TRUE;

			-- Do not produce classification for the same date and patient
			ELSE
				RETURN FALSE;
		END CASE;
	END transduceclassification;

	/*
	 *  Overloaded transduction of the internal intermediate state to the output clinical
	 *  classification, this produces the actual classification.
	 */
	FUNCTION transduceclassification
	(
		currentstate internalstate
	)
	RETURN outputclassification AS
		returnclassification outputclassification;
	BEGIN

		-- To do add transformation logic, example always producing a final record
		returnclassification.uliabphn := currentstate.uliabphn;
		returnclassification.classificationdate := currentstate.statedate;
		CASE

			-- Never been infected
			WHEN currentstate.patientinfections < 1 THEN
				returnclassification.infectionstatus := 'Susceptible';

			-- Remission of infection
			WHEN currentstate.currentinfected = 0 THEN
				returnclassification.infectionstatus := 'Remission';

			-- Continued infection
			WHEN currentstate.previousinfected = 1 THEN
				returnclassification.infectionstatus := 'Continued infection';

			-- First infection
			WHEN currentstate.patientinfections = 1 THEN
				returnclassification.infectionstatus := 'New infection';
			
			-- Reinfections
			ELSE
				returnclassification.infectionstatus := 'Reinfection';
		END CASE;
		RETURN returnclassification;
	END transduceclassification;
END clinicalclassifier;
CREATE OR REPLACE PACKAGE BODY syphilisclassifier AS
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
		to_number(a0.phn_numeric) uliabphn,
		TRUNC(a0.collection_dt_tm) assaydate,
		a0.order_mnemonic assayidentifier,
		a0.result_test assaydescription,
    a0.result_value_text resultdescription,
    CASE a0.order_mnemonic
      WHEN '.RPR' THEN
        '2-RPR'
      WHEN '.INNO SYPH' THEN
        '1-TPPA-INNO'
      WHEN '.TPPA' THEN
        '1-TPPA-INNO'
      ELSE
        '0-EIA'
    END assayorder,
    CASE
      WHEN upper(a0.result_value_text) = 'REACTIVE' THEN
        1
      WHEN upper(a0.result_value_text) = 'POSITIVE' THEN
        1
      WHEN upper(a0.result_value_text) LIKE '%DIL%' THEN
        COALESCE(to_number(regexp_substr(a0.result_value_text, '[0-9]*')), 0)
      ELSE
        0
    END assayresult
	FROM
		prep_final_lab_may21 a0
  WHERE
    (a0.order_mnemonic = '.INNO SYPH' AND a0.result_test = 'Syphilis Inno-LIA Score')
    OR
    (a0.order_mnemonic = '.TPPA' AND a0.result_test = 'Syphilis TPPA')
    OR
    (a0.order_mnemonic = '.RPR')
    OR
    (a0.order_mnemonic = 'SYPH PROV' AND a0.result_test = 'Syphilis EIA')
    OR
    (a0.order_mnemonic = 'SYPH' AND a0.result_test = 'SYPH')
    OR
    (a0.result_test = 'Prenatal Syphilis EIA')
	ORDER BY
		1 ASC NULLS FIRST,
		2 ASC NULLS FIRST,
    6 ASC NULLS FIRST,
    7 ASC NULLS FIRST;

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
    nextstate.currentdilution := 0;
    nextstate.previousdilution := 0;
    nextstate.EIAtrigger := 0;
    nextstate.TPPAtrigger := 0;
    nextstate.RPRtrigger := 0;
  
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
        nextstate.currentdilution := 0;
        nextstate.previousdilution := 0;
        nextstate.EIAtrigger := 0;
        nextstate.TPPAtrigger := 0;
        nextstate.RPRtrigger := 0;

			-- Process new date for the same patient, begin day by assuming negative assays
			WHEN currentstate.statedate < nextobservation.assaydate THEN
				nextstate.patientinfections := currentstate.patientinfections;
				nextstate.currentinfected := 0;
				nextstate.previousinfected := currentstate.currentinfected;
        nextstate.currentdilution := 0;
        nextstate.previousdilution := currentstate.currentdilution;
        nextstate.EIAtrigger := 0;
        nextstate.TPPAtrigger := 0;
        nextstate.RPRtrigger := 0;

			-- Pull forward observations for the same date and patient
			ELSE
				nextstate.patientinfections := currentstate.patientinfections;
				nextstate.currentinfected := currentstate.currentinfected;
				nextstate.previousinfected := currentstate.previousinfected;
        nextstate.currentdilution := currentstate.currentdilution;
        nextstate.previousdilution := currentstate.previousdilution;
        nextstate.EIAtrigger := currentstate.EIAtrigger;
        nextstate.TPPAtrigger := currentstate.TPPAtrigger;
        nextstate.RPRtrigger := currentstate.RPRtrigger;
		END CASE;

    -- Toggle the triggers on the tests
    CASE nextobservation.assayorder
    
      -- Trigger the EIA reactive flag
      WHEN '0-EIA' THEN
        nextstate.EIAtrigger := greatest(nextstate.EIAtrigger, nextobservation.assayresult);
        
      -- Trigger the TPPA reactive flag
      WHEN '1-TPPA-INNO' THEN
        nextstate.TPPAtrigger := greatest(nextstate.TPPAtrigger, nextobservation.assayresult);
        
      --Assign the largest RPR dilution observed so far on the day
      ELSE
        nextstate.currentdilution := greatest(nextstate.currentdilution, nextobservation.assayresult);
    END CASE;

    -- Trigger the RPR by the dilution numbers
    CASE
    
      -- Previous (from before) RPR and next (right now) are non-reactive or not reactive enough
      WHEN nextstate.currentdilution < 2 THEN
        nextstate.RPRtrigger := 0;
        
      -- Four fold increase in dilution number or previous non-reactive, 
      -- and next is reactive with at least 2 dilutions
      WHEN 4 * currentstate.previousdilution <= nextstate.currentdilution THEN
        nextstate.RPRtrigger := 1;
      
      -- Insufficient increase
      ELSE
        nextstate.RPRtrigger := 0;
    END CASE;      
    
    -- Determine infections status
    CASE
    
      -- EIA and TPPA triggered
      WHEN nextstate.currentinfected = 0 AND nextstate.previousinfected = 0 AND nextstate.EIAtrigger = 1 AND nextstate.TPPAtrigger = 1 THEN
        nextstate.currentinfected := 1;
        nextstate.patientinfections := 1 + nextstate.patientinfections;
    
      -- EIA and TPPA triggered
      WHEN nextstate.EIAtrigger = 1 AND nextstate.TPPAtrigger = 1 THEN
        nextstate.currentinfected := 1;
  
      -- EIA and RPR triggered
      WHEN nextstate.currentinfected = 0 AND nextstate.previousinfected = 0 AND nextstate.EIAtrigger = 1 AND nextstate.RPRtrigger = 1 THEN
        nextstate.currentinfected := 1;
        nextstate.patientinfections := 1 + nextstate.patientinfections;
  
      -- EIA and RPR triggered
      WHEN nextstate.EIAtrigger = 1 AND nextstate.RPRtrigger = 1 THEN
        nextstate.currentinfected := 1;
  
      -- No op
      ELSE
        NULL;
    END CASE;

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
    returnclassification.infectioncount := currentstate.patientinfections;
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
END syphilisclassifier;
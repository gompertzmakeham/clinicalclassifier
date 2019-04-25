# Clinical Classifier
Meta-framework for a Mealy finite state transducer to implement clinical classification as a stochastic process adapted to the filtration of sigma-algebra refinements by sequential clinical observations.

Stub package outlining the meta-framework for implementing clinical classification algorithms as Mealy finite state transducer. The theory behind this implementation is that clinical classification is a stochastic process adapted to the filteration of the sigma-algebra refinements by sequential clinical observation. However, clinicians know a priori how many observations they have requested and will only make a decision after recieving the all the order observations. Unfortunately those inter-observation relationships are rarely recorded in our longitudinal data sets. As a heuristic to address this limitation we implement the decision proceess with a preemptive transducer that determines if a clinical observation should be produced by comparing the current state to the incoming observation that will drive the change in state. This allows, for example, classifications to be produced only at the end of the day, or the change in the patient. This is the simplest possible Mealy dependency as only the existence of an output depends on the transition, the actual values are transduced from the state.

This package is a working example that implements the toy model of:

    susceptible -> new infection -> continued infection -> remission -> reinfection

The internal state counts infections based off of an asborbing detector of positive assays.

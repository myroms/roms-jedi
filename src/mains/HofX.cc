/*
 * (C) Copyright 2019-2020 UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "socaroms/Traits.h"
#include "oops/runs/HofX.h"
#include "oops/runs/Run.h"
#include "oops/generic/instantiateModelFactory.h"
#include "ufo/instantiateObsFilterFactory.h"
#include "ufo/ObsTraits.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  oops::instantiateModelFactory<socaroms::Traits>();
  ufo::instantiateObsFilterFactory<ufo::ObsTraits>();
  oops::HofX<socaroms::Traits, ufo::ObsTraits> hofx;
  return run.execute(hofx);
}

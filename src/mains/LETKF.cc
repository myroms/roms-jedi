/*
 * (C) Copyright 2019-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "oops/runs/LocalEnsembleDA.h"
#include "oops/runs/Run.h"
#include "ufo/instantiateObsErrorFactory.h"
#include "ufo/instantiateObsFilterFactory.h"
#include "ufo/instantiateObsLocFactory.h"
#include "ufo/ObsTraits.h"

#include "romsjedi/Traits.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  ufo::instantiateObsLocFactory<romsjedi::Traits>();
  ufo::instantiateObsErrorFactory();
  ufo::instantiateObsFilterFactory();
  oops::LocalEnsembleDA<romsjedi::Traits, ufo::ObsTraits> letkf;
  return run.execute(letkf);
}

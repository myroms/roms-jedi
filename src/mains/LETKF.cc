/*
 * (C) Copyright 2019-2020 UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "roms/Traits.h"
#include "oops/runs/Run.h"
#include "ioda/instantiateObsLocFactory.h"
#include "oops/runs/LocalEnsembleDA.h"
#include "ufo/instantiateObsFilterFactory.h"
#include "ufo/ObsTraits.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  ioda::instantiateObsLocFactory<ufo::ObsTraits>();
  ufo::instantiateObsFilterFactory<ufo::ObsTraits>();
  oops::LocalEnsembleDA<roms::Traits, ufo::ObsTraits> letkf;
  return run.execute(letkf);
}

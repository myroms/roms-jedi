/*
 * (C) Copyright 2019-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "oops/generic/instantiateModelFactory.h"
#include "oops/runs/Run.h"
#include "oops/runs/Variational.h"
#include "saber/oops/instantiateCovarFactory.h"
#include "ufo/instantiateObsErrorFactory.h"
#include "ufo/instantiateObsFilterFactory.h"
#include "ufo/ObsTraits.h"

#include "romsjedi/Traits.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  oops::instantiateModelFactory<romsjedi::Traits>();
  ufo::instantiateObsErrorFactory();
  ufo::instantiateObsFilterFactory();
  saber::instantiateCovarFactory<romsjedi::Traits>();
  oops::Variational<romsjedi::Traits, ufo::ObsTraits> var;
  return run.execute(var);
}

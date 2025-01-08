/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "oops/runs/EnsembleApplication.h"
#include "oops/runs/Run.h"
#include "oops/runs/Variational.h"
#include "saber/oops/instantiateCovarFactory.h"
#include "ufo/instantiateObsErrorFactory.h"
#include "ufo/instantiateObsFilterFactory.h"
#include "ufo/ObsTraits.h"

#include "romsjedi/Traits.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  saber::instantiateCovarFactory<romsjedi::Traits>();
  ufo::instantiateObsErrorFactory();
  ufo::instantiateObsFilterFactory();
  oops::EnsembleApplication<oops::Variational <romsjedi::Traits,
                                               ufo::ObsTraits> > eda;
  return run.execute(eda);
}

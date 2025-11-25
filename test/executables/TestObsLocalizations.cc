/*
 * (C) Copyright 2019-2025 UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "oops/runs/Run.h"
#include "test/base/ObsLocalizations.h"
#include "ufo/instantiateObsLocFactory.h"
#include "ufo/ObsTraits.h"

#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/Traits.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  ufo::instantiateObsLocFactory<romsjedi::GeometryIterator>();
  test::ObsLocalizations<romsjedi::Traits, ufo::ObsTraits> tests;
  return run.execute(tests);
}

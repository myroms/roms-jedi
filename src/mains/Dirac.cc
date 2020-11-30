/*
 * (C) Copyright 2019-2020 UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "roms/Traits.h"

#include "oops/runs/Dirac.h"
#include "oops/runs/Run.h"
//  #include "saber/oops/instantiateLocalizationFactory.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  //  saber::instantiateLocalizationFactory<roms::Traits>();
  oops::Dirac<roms::Traits> dir;
  return run.execute(dir);
}

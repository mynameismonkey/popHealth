namespace :upgrade do

  task :upgrade_query_cache => :environment do
    # remove all unprocessed jobs - they will not be compatible with the updated 
    # QME. 
    Delayed::Job.all.destroy
    fields = ["population_ids",
              "IPP",
              "DENOM"
              "NUMER",
              "antinumerator",
              "DENEX",
              "DENEXCEP",
              "MSRPOPL",
              "OBSERV", 
              "supplemental_data"]
    QME::QualityReport.where({status: nil}).each do |qr|
      qr.status = {state: "completed"}
      report = QME::QualityReportResult.new
      fields.each do |f|
        report[field] = qr[field]
      end
      qr.report = report
      qr.save
    end

  end

  task :upgrade_records => :environment do 
    Record.all.each do |r|

    end
  end

  task :upgrade_patient_cache => :environment do
    QME::PatientCache.all.each do |pc|

    end
  end

  task :upgrade_providers => :environment do
    Provider.all.each do |pro|
      cda_ids = []
      cda_ids << {root: "2.16.840.1.113883.4.6", extension: pro["npi_id"] } if pro["npi_id"]
      cda_ids << {root: "2.16.840.1.113883.4.2", extension: pro["tin_id"] } if pro["tin_id"]   
      pro.cda_identifiers = cda_ids
      pro.save
    end
  end

  task :upgrade_users => :environment do 
    Users.all.each do |u|
      selected = Mongoid.default_session["selected_measures"].where({username: u.username}).collect{|sm| sm["id"]}
      u.preferences["selected_measure_ids"] = selected
      u.save
    end
  end

end
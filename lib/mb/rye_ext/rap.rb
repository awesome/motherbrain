module Rye
  class Rap < Array
    def to_hash
      {
        exit_status: self.exit_status,
        exit_signal: self.exit_signal,
        stderr: self.stderr,
        stdout: self.stdout
      }
    end
  end
end

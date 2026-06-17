package org.springframework.samples.petclinic.owner;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class OwnerRestController {

	private final OwnerRepository owners;

	public OwnerRestController(OwnerRepository owners) {
		this.owners = owners;
	}

	@GetMapping("/api/owners")
	public List<Owner> getOwnersJson(@RequestParam(defaultValue = "") String lastName,
			@RequestParam(defaultValue = "1") int page) {
		int pageSize = 100;
		Pageable pageable = PageRequest.of(page - 1, pageSize);
		Page<Owner> ownersResults = this.owners.findByLastNameStartingWith(lastName, pageable);
		return ownersResults.getContent();
	}

}

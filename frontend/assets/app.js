(function () {
  "use strict";

  const config = window.PETCLINIC_CONFIG || {};

  const elements = {
    openApp: document.getElementById("open-app"),
    vetsLink: document.getElementById("vets-link"),
    addOwner: document.getElementById("add-owner-link"),
    navFindOwners: document.getElementById("nav-find-owners"),
    navVets: document.getElementById("nav-vets"),
    navAddOwner: document.getElementById("nav-add-owner")
  };

  const ownersPageUrl = "./owners/index.html";
  const vetsPageUrl = "/vets.html";
  const addOwnerPageUrl = "/owners/new";

  if (elements.openApp) setLink(elements.openApp, ownersPageUrl);
  if (elements.vetsLink) setLink(elements.vetsLink, vetsPageUrl);
  if (elements.addOwner) setLink(elements.addOwner, addOwnerPageUrl);
  if (elements.navFindOwners) setLink(elements.navFindOwners, ownersPageUrl);
  if (elements.navVets) setLink(elements.navVets, vetsPageUrl);
  if (elements.navAddOwner) setLink(elements.navAddOwner, addOwnerPageUrl);

  function setLink(element, url) {
    element.href = url;
    element.removeAttribute("aria-disabled");
  }
}());
